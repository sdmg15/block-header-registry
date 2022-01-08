pragma solidity ^0.8.0;

import "./BlockHeaderRegistry.sol";

contract BlockHeaderRegistryMock is BlockHeaderRegistry {
	address immutable deployer;
    constructor() BlockHeaderRegistry(msg.sender) {
		deployer = msg.sender;
	}

    function parseBlock(bytes calldata rlpHeader)
        public
        view
        returns (BlockHeader memory header)
    {
        return _parseBlock(rlpHeader);
    }

    function _rlpEncode(BlockHeader memory header)
        public
        view
        returns (bytes memory rlp)
    {
        rlp = abi.encode(header);
    }

    function _hashBlock(BlockHeader memory header)
        public
        returns (bytes memory rlp, bytes32 blockHash)
    {
        blockHash = keccak256(_rlpEncode(header));
    }

      function _isValidator(address person) internal override returns (bool) {
		return person == votingContract;
	}
}
