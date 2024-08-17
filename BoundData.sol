// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";

contract BoundData {
    using Strings for uint256;

    string internal svgStart =
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 700 700" width="700" height="700"><style type="text/css">.st1 {fill: none; stroke-width: 1; stroke-linecap: round; stroke-linejoin: round; stroke-miterlimit: 10;}</style><rect width="700" height="700" fill="#000000"/>';

    string internal svgEnd = "</svg>";

    bytes hexSymbols = "0123456789abcdef";
    

    // Returns the color of the pixel at the given coordinates
    function getColor(uint256 value) internal view returns (string memory) {
        bytes memory hexColor = new bytes(6);
        for (uint256 i = 0; i < 6; i++) {
            hexColor[5 - i] = hexSymbols[value & 0xf];
            value >>= 4;
        }
        return string(hexColor);
    }

    // X is not a valid hex color, so we get a random number between 0-255 and convert it to hex and replace 0x
    function getModifiedAddress(address _address) internal view returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(_address));
        uint256 randomNumber = uint256(uint8(hash[0])) % 256;
        string memory hexValue = toHex(randomNumber);

        // Convert address to string and remove 0x prefix
        string memory addressHex = addressToString(_address);

        // Concatenate the hexValue with the rest of the address
        return string(abi.encodePacked(hexValue, addressHex));
    }

    // convert address to string for processing
    function addressToString(address _address) internal view returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(_address);
        bytes memory hexString = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            hexString[i * 2] = hexSymbols[uint8(addressBytes[i] >> 4)];
            hexString[i * 2 + 1] = hexSymbols[uint8(addressBytes[i] & 0x0f)];
        }
        return string(hexString);
    }

    // convert random number to a hex
    function toHex(uint256 value) internal view returns (string memory) {
        bytes memory hexString = new bytes(2);
        for (uint256 i = 0; i < 2; i++) {
            hexString[1 - i] = hexSymbols[value & 0xf];
            value >>= 4;
        }
        return string(hexString);
    }

    /// @notice Returns an SVG string based on the address
    function addressToSVG(address _address) internal view returns (string memory) {
        string memory modifiedAddress = getModifiedAddress(_address);
        string memory svgContent = svgStart;

        for (uint256 i = 0; i < 7; i++) {
            bytes memory chunk = new bytes(6);
            for (uint256 j = 0; j < 6; j++) {
                chunk[j] = bytes(modifiedAddress)[i * 6 + j];
            }
            string memory color = string(chunk);
            svgContent = string(
                abi.encodePacked(
                    svgContent,
                    '<rect x="',
                    (i * 100).toString(),
                    '" y="0" width="100" height="700" fill="#',
                    color,
                    '" />'
                )
            );
        }

        svgContent = string(abi.encodePacked(svgContent, svgEnd));
        return svgContent;
    }

    /// @notice Returns an array of 7 colors based on the address
    function colorArray(address _address) internal view returns (string[7] memory) {
        string memory modifiedAddress = getModifiedAddress(_address);
        string[7] memory colors;

        for (uint256 i = 0; i < 7; i++) {
            bytes memory chunk = new bytes(6);
            for (uint256 j = 0; j < 6; j++) {
                chunk[j] = bytes(modifiedAddress)[i * 6 + j];
            }
            colors[i] = string(chunk);
        }

        return colors;
    }
}