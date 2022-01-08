pragma solidity ^0.8.0;

import './BlockHeaderRegistry.sol';

contract BlockHeaderRegistryMock is BlockHeaderRegistry {
	constructor() BlockHeaderRegistry(address(0)) {}

	function _rlpEncode(BlockHeader memory header) public view returns (bytes memory rlp) {
		rlp = abi.encode(header);
	}

	function _hashBlock(BlockHeader memory header) public returns (bytes memory rlp, bytes32 blockHash) {
		blockHash = keccak256(_rlpEncode(header));
	}
}
