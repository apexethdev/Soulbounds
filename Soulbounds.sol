// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721A} from "ERC721A/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "./base64.sol";
import {BoundData} from "./BoundData.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Soulbounds - A combination of concepts from Base Colors and Waveforms
 * @notice Apex777.eth x 0FJAKE.eth collaboration
 * @dev Mint Soulbound NFTs with unique colors based on the owner's address.
 * @dev SVG images are generated on-chain and stored fully on-chain on Base.
 */
interface IBaseColors {
    function getAttributesAsJson(uint256 tokenId) external view returns (string memory);

    struct ColorData {
        uint256 tokenId;
        bool isUsed;
        uint256 nameChangeCount;
        string[] modifiableTraits;
    }

    function getColorData(string memory color) external view returns (ColorData memory);
}

contract Soulbounds is Ownable, ReentrancyGuard, ERC721A, BoundData {
    using Strings for uint256;

    bool public mintEnabled = false;
    uint256 public mintPrice = 0.001 ether;
    mapping(address => bool) public hasMinted;

    address public baseColorsAddress;
    IBaseColors private baseColors;

    address private jakeAddress = payable(0x3415CD5FcAa35F986c8129c7a80E3AF75e5cF262);
    address private apexAddress = payable(0xd91c4283eBbc00aF162B73418Ec4ab0B3c159900);

    constructor() Ownable(msg.sender) ERC721A("Soulbounds", "SOUL") {
        baseColorsAddress = 0x7Bc1C072742D8391817EB4Eb2317F98dc72C61dB; /// base
        baseColors = IBaseColors(baseColorsAddress);
    }

    /**
     * @dev Start token ID for the collection is 1.
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev Mint 1 Soulbound NFT.
     */
    function mint() external payable {
        uint256 cost = mintPrice;

        require(mintEnabled, "Mint not started");
        require(!hasMinted[msg.sender], "Address has already minted an NFT");
        require(msg.value == cost, "Please send the exact ETH amount");

        _safeMint(msg.sender, 1);
        hasMinted[msg.sender] = true;

        uint256 split = msg.value / 2;

        (bool jakeSuccess,) = jakeAddress.call{value: split}("");
        require(jakeSuccess, "Transfer to jakeAddress failed.");

        (bool apexSuccess,) = apexAddress.call{value: split}("");
        require(apexSuccess, "Transfer to apexAddress failed.");
    }

    /**
     * @dev tokenURI override to return JSON metadata with SVG image and attributes.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        // Get image
        string memory image = buildSVG(tokenId);

        // Encode SVG data to base64
        string memory base64Image = Base64.encode(bytes(image));

        // Get attributes JSON
        string memory attributes = buildAttributesJSON(tokenId);

        // Build JSON metadata
        string memory json = string(
            abi.encodePacked(
                '{"name":"Soulbound #',
                Strings.toString(tokenId),
                '","description":"Soulbounds are non-transferable NFTs generated from your unique ETH address using Base Colors.","attributes":',
                attributes,
                ',"image":"data:image/svg+xml;base64,',
                base64Image,
                '"}'
            )
        );

        // Encode JSON data to base64
        string memory base64Json = Base64.encode(bytes(json));

        // Construct final URI
        return string(abi.encodePacked("data:application/json;base64,", base64Json));
    }

    /**
     * @dev build the attributes JSON for the NFT.
     */
    function buildAttributesJSON(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        address owner = ownerOf(tokenId);

        string[7] memory colors = colorArray(owner);
        string memory attributes = "[";

        for (uint256 i = 0; i < 7; i++) {
            // check if color is in baseColors contract
            string memory name = getColorName(colors[i]);

            attributes = string(
                abi.encodePacked(
                    attributes, '{"trait_type":"Color ', Strings.toString(i + 1), '","value":"', name, '"}'
                )
            );
            if (i < 6) {
                attributes = string(abi.encodePacked(attributes, ","));
            }
        }
        attributes = string(abi.encodePacked(attributes, "]"));

        return attributes;
    }

    /**
     * @dev Check if this color has a name in the baseColors contract.
     */
    function getColorName(string memory colorhex) internal view returns (string memory) {
        // Concatenate "#" with the colorhex
        string memory colorWithHash = string(abi.encodePacked("#", colorhex));

        try baseColors.getColorData(colorWithHash) returns (IBaseColors.ColorData memory colorData) {
            // Start finding the color name
            // Get the attributes JSON string for the color
            string memory attributes = baseColors.getAttributesAsJson(colorData.tokenId);

            // Extracting the color name from the attributes JSON string
            bytes memory attributesBytes = bytes(attributes);
            bytes memory colorNameKey = bytes('"trait_type":"Color Name","value":"');
            bytes memory endKey = bytes('"}');

            // Finding the start position of the color name
            uint256 start = 0;
            for (uint256 i = 0; i < attributesBytes.length - colorNameKey.length; i++) {
                bool ismatched = true;
                for (uint256 j = 0; j < colorNameKey.length; j++) {
                    if (attributesBytes[i + j] != colorNameKey[j]) {
                        ismatched = false;
                        break;
                    }
                }
                if (ismatched) {
                    start = i + colorNameKey.length;
                    break;
                }
            }

            // Finding the end position of the color name
            uint256 end = start;
            for (uint256 i = start; i < attributesBytes.length - endKey.length; i++) {
                bool ismatched = true;
                for (uint256 j = 0; j < endKey.length; j++) {
                    if (attributesBytes[i + j] != endKey[j]) {
                        ismatched = false;
                        break;
                    }
                }
                if (ismatched) {
                    end = i;
                    break;
                }
            }

            // Extracting the color name
            bytes memory colorNameBytes = new bytes(end - start);
            for (uint256 i = 0; i < end - start; i++) {
                colorNameBytes[i] = attributesBytes[start + i];
            }

            return string(colorNameBytes);
        } catch {
            // If the call to getColorData fails, color not minted. return the hex color.
            return colorhex;
        }
    }

    /**
     * @dev build the SVG image for the NFT. Handy for front-end / testing.
     */
    function buildSVG(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        address holder = ownerOf(tokenId);
        string memory svg = addressToSVG(holder);

        return svg;
    }

    /**
     * @dev Get the colors for an address or token ID.
     */
    function getColorsForAddress(address _address) public view returns (string[7] memory) {
        string[7] memory colors = colorArray(_address);
        return colors;
    }

    /**
     * @dev Get the colors for a token ID.
     */
    function getColorsForToken(uint256 tokenId) public view returns (string[7] memory) {
        address holder = ownerOf(tokenId);
        string[7] memory colors = colorArray(holder);
        return colors;
    }

    /**
     * @dev Soulbound NFTs cannot be transferred, overridden to revert.
     * approve + setApprovalForAll + _beforeTokenTransfers are also overridden to revert.
     */
    function approve(address, uint256) public payable virtual override {
        revert("Token is soulbound and cannot be approved for transfer");
    }

    function setApprovalForAll(address, bool) public virtual override {
        revert("Token is soulbound and cannot be approved for transfer");
    }

    function _beforeTokenTransfers(address from, address to, uint256, uint256) internal virtual override {
        require(from == address(0) || to == address(0), "Token is soulbound and cannot be transferred");
    }

    /**
     * @dev toggle mint on and off.
     */
    function toggleMinting() external onlyOwner {
        mintEnabled = !mintEnabled;
    }

    /**
     * @dev ETH is sent to wallets, but keep this just in case.
     */
    function withdraw() external onlyOwner nonReentrant {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
