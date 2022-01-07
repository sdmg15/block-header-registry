/**

	The purpose of this contract is to store on Fuse block headers from different blockchains signed by the Fuse validators.

**/
contract BlockHeaderRegistry {

	struct SignedBlock {
	 bytes[] signatures;
	 uint256 cycleEnd;
	 // just for fuse
	 address[] validators;
	 // to prevent double signatures
	 mapping(address => bool) hasValidatorSigned;
	}

	struct BlockHeader {
	  bytes32 parent_hash;
	  uint256 timestamp;
	  uint256 number;
	  address author;
	  bytes32 transactions_root;
	  bytes32 uncles_hash;
	  bytes extra_data;
	  bytes32 state_root;
	  bytes32 receipts_root;
	  bytes log_bloom;
	  uint256 gas_used;
	  uint256 gas_limit;
	  uint256 difficulty;
	  bytes32 mixHash;
	  uint256 nonce;
	}

	struct Block {
	 BlockHeader header;
	 bytes signature;
	 uint256 blockchainId;
	 bytes32 blockHash;
	 address[] validators;
	 uint256 cycleEnd;
	}

	// Block hashes per block number for blockchain
	mapping(uint256 => mapping(uint256 => bytes32[])) public blockHashes;

	// Validator signatures per blockHash
	mapping(bytes32 => SignedBlock) public blockSignatures;

	// Block header for blockHash
	mapping(bytes32 => BlockHeader) public blockHeaders

	address private votingContract;

	event Blockchain(
		uint256 blockchainId,
		string rpc
	);
	modifier onlyVoting() {
		require(msg.sender == votingContract);
		_;
	}
	function addBlockchain(uint256 blockchainId, string memory rpc) external onlyVoting {
		blockchains[blockchainId] = rpc;
		emit Blockchain(blockchainId, rpc);
	}

	modifier onlyValidator() {
		require(_isValidator(msg.sender));
		_;
	}
	function addSignedBlocks(Block[] memory blocks) external onlyValidator {
		for(uint256 i = 0; i < blocks.length; i ++) {
			Block memory block = blocks[i];
			if (blocks[i].blockchainId == block.chainid) {
				_addFuseSignedBlock(block.header, block.signature, block.blockHash, block.validators, block.cycleEnd);
			} else {
				_addSignedBlock(block.header, block.signature, block.blockchainId, block.blockHash);
			}
		}
	}

	function getSignedBlock(uint256 blockchainId, uint256 number) public view returns (bytes rlpHeader, bytes[] memory signatures, address[] memory validators, uint256 cycleEnd) {
		bytes32[] memory _blockHashes = blockHashes[blockchainId][number];
		require(_blockHashes.length != 0)
		bytes32 highest = _blockHashes[0];
		for (uint256 i = 1; i < _blockHashes.length; i++) {
			if (_blockHashes[i] > highest) highest = _blockHashes[i];
		}
		SignedBlock storage block = blockSignatures[highest];
		return (abi.encode(blockHeaders[highest]), block.signatures, block.validators, block.cycleEnd);
	}

	function _addSignedBlock(BlockHeader memory blockHeader, bytes signature, uint256 blockchainId, bytes32 blockHash) internal {
		require(_hashHeader(blockHeader) == blockHash);
		address signer = ECDSA.recover(blockHash, signature);
		require(_isValidator(signer));
		require(!blockSignatures[blockHash].hasValidatorSigned[signer]);
		if (_isNewBlock(blockHash)) {
			blockHeaders[blockHash] = blockHeader;
			blockHashes[blockchainId][blockHeader.number].push(blockHash);
		}
		blockSignatures[blockHash].hasValidatorSigned[signer] = true;
		blockSignatures[blockHash].signatures.push(signature);
	}

	function _addFuseSignedBlock(BlockHeader memory blockHeader, bytes signature, address[] memory validators, uint256 cycleEnd) internal {
		require(_hashHeader(blockHeader) == blockHash);
		bytes32 payload = keccak256(abi.encode(blockHash, validators, cycleEnd);
		address signer = ECDSA.recover(payload, signature);
		require(_isValidator(signer));
		require(!blockSignatures[payload].hasValidatorSigned[signer]);
		if (_isNewBlock(payload)) {
			blockHeaders[payload] = blockHeader;
			blockSignatures[payload].validators = validators;
			blockSignatures[payload].cycleEnd = cycleEnd;
			blockHashes[block.chainid][blockHeader.number].push(payload);
		}
		blockSignatures[payload].hasValidatorSigned[signer] = true;
		blockSignatures[payload].signatures.push(signature);
	}

	function _isValidator(address person) internal virtual returns (bool);

	function _isNewBlock(bytes32 key) private returns (bool) {
		return blockSignatures[payload].signatures.length == 0;
	}
}
