pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**

	The purpose of this contract is to store on Fuse block headers 
	from different blockchains signed by the Fuse validators.

**/
contract BlockHeaderRegistry {

	// To prevent double signatures
	mapping(bytes32 => mapping(address => bool)) hasValidatorSigned;

	struct SignedBlock {
		bytes[] signatures;
		// Just for fuse 
		uint256 cycleEnd;
		address[] validators;
	}

	struct BlockHeader {
		bytes32 parentHash;
		bytes32 uncleHash;
		address coinbase;
		bytes32 root;
		bytes32 txHash;
		bytes32 receiptHash;
		bytes bloom;
		uint256 difficulty;
		uint256 number;
		uint256 gasLimit;
		uint256 gasUsed;
		uint256 time;
		bytes extra;
		bytes32 mixDigest;
		uint256 nonce;
		// uint256 baseFee;
	}

	struct Block {
		BlockHeader header;
		bytes signature;
		uint256 blockchainId;
		bytes32 blockHash;
		uint256 cycleEnd;
		address[] validators;
	}

	// Block hashes per block number for blockchain
	mapping(uint256 => mapping(uint256 => bytes32[])) public blockHashes;

	// Validator signatures per blockHash
	mapping(bytes32 => SignedBlock) public signedBlocks;

	// Block header for blockHash
	mapping(bytes32 => BlockHeader) blockHeaders;

	mapping(uint256 => string) public blockchains;

	address private votingContract;

	constructor(address _votingContract) {
		votingContract = _votingContract == address(0) ? msg.sender: _votingContract;
	}

	event Blockchain(
		uint256 blockchainId,
		string rpc
	);
	modifier onlyVoting() {
		require(msg.sender == votingContract, 'onlyVoting');
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

	function addSignedBlocks(Block[] calldata blocks) external onlyValidator {
		for (uint256 i = 0; i < blocks.length; i ++) {
			Block memory  _block = blocks[i];
			if (_block.blockchainId == block.chainid) {
				_addFuseSignedBlock(_block.header, _block.signature, _block.blockHash, _block.validators, _block.cycleEnd);
			} else {
				_addSignedBlock(_block.header, _block.signature, _block.blockchainId, _block.blockHash);
			}
		}
	}

	function getSignedBlock(uint256 blockchainId, uint256 number) public view returns (bytes32 blockHash, BlockHeader memory blockHeader, SignedBlock memory signedBlock) {
		bytes32[] memory _blockHashes = blockHashes[blockchainId][number];
		require(_blockHashes.length != 0);
		blockHash = _blockHashes[0];
		for (uint256 i = 1; i < _blockHashes.length; i++) {
			if (_blockHashes[i] > blockHash) blockHash = _blockHashes[i];
		}
		SignedBlock storage _block = signedBlocks[blockHash];
		signedBlock.signatures = _block.signatures;
		if (blockchainId == block.chainid) {
			signedBlock.validators = _block.validators;
			signedBlock.cycleEnd = _block.cycleEnd;
		}
		{
			
			blockHeader = blockHeaders[blockHash];
		}
	}

	function _addSignedBlock(BlockHeader memory blockHeader, bytes memory signature, uint256 blockchainId, bytes32 blockHash) internal {
		require(keccak256(abi.encode(blockHeader)) == blockHash);
		address signer = ECDSA.recover(blockHash, signature);
		require(_isValidator(signer));
		require(!hasValidatorSigned[blockHash][signer]);
		if (_isNewBlock(blockHash)) {
			blockHeaders[blockHash] = blockHeader;
			blockHashes[blockchainId][blockHeader.number].push(blockHash);
		}
		hasValidatorSigned[blockHash][signer] = true;
		signedBlocks[blockHash].signatures.push(signature);
	}

	function _addFuseSignedBlock(BlockHeader memory blockHeader, bytes memory signature, bytes32 blockHash, address[] memory validators, uint256 cycleEnd) internal {
		require(keccak256(abi.encode(blockHeader)) == blockHash);
		bytes32 payload = keccak256(abi.encode(blockHash, validators, cycleEnd));
		address signer = ECDSA.recover(payload, signature);
		require(_isValidator(signer));
		require(!hasValidatorSigned[payload][signer]);
		if (_isNewBlock(payload)) {
			blockHeaders[payload] = blockHeader;
			signedBlocks[payload].validators = validators;
			signedBlocks[payload].cycleEnd = cycleEnd;
			blockHashes[block.chainid][blockHeader.number].push(payload);
		}
		hasValidatorSigned[payload][signer] = true;
		signedBlocks[payload].signatures.push(signature);
	}

	function _isValidator(address person) internal virtual returns (bool) {
		return person == votingContract;
	}

	function _isNewBlock(bytes32 key) private view returns (bool) {
		return signedBlocks[key].signatures.length == 0;
	}
}
