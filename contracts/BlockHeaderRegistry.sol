pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**

	The purpose of this contract is to store on Fuse block headers 
	from different blockchains signed by the Fuse validators.

**/
contract BlockHeaderRegistry {

	// To prevent double signatures
	mapping(bytes32 => mapping(address => bool)) hasValidatorSigned;


	struct Signature {
		bytes32 r;
		bytes32 vs;
	}

	struct SignedBlock {
		address creator;
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
		bytes32[8] bloom;
		uint256 difficulty;
		uint256 number;
		uint256 gasLimit;
		uint256 gasUsed;
		uint256 time;
		bytes32 mixDigest;
		uint256 nonce;
		uint256 baseFee;
		// This can be arbitrary length on some chains
		bytes extra;
	}

	struct Block {
		bytes rlpHeader;
		Signature signature;
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

	address votingContract;

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
		require(_isValidator(msg.sender), 'onlyValidator');
		_;
	}

	/**
		@notice Add a signed block from any blockchain.
		@notice Costs slightly more if the block has never been registered before.
		@notice Processes fuse blocks slightly differently.
		@param blocks List of block headers and signatures to add.
	*/
	function addSignedBlocks(Block[] calldata blocks) external onlyValidator {
		for (uint256 i = 0; i < blocks.length; i ++) {
			Block calldata  _block = blocks[i];
			bytes32 rlpHeaderHash = keccak256(_block.rlpHeader);
			require(rlpHeaderHash == _block.blockHash, "rlpHeaderHash");
			bool isFuse = _isFuse(_block.blockchainId);
			bytes32 payload = isFuse ? keccak256(abi.encodePacked(rlpHeaderHash, _block.validators, _block.cycleEnd)) : rlpHeaderHash;
			address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(payload), _block.signature.r, _block.signature.vs);
			require(msg.sender == signer, "msg.sender == signer");
			require(!hasValidatorSigned[payload][msg.sender], 'hasSigned');
			hasValidatorSigned[payload][signer] = true;
			if (_isNewBlock(payload)) {
	                        BlockHeader memory blockHeader = _parseBlock(_block.rlpHeader);
	                        blockHeaders[payload] = blockHeader;
	                        blockHashes[_block.blockchainId][blockHeader.number].push(payload);
				if (isFuse) {
					signedBlocks[payload].validators = _block.validators;
					signedBlocks[payload].cycleEnd = _block.cycleEnd;
				}
				signedBlocks[payload].creator = msg.sender;
			}
			signedBlocks[payload].signatures.push(abi.encodePacked(_block.signature.r, _block.signature.vs));
		}
	}

	function _parseBlock(bytes calldata rlpHeader) internal virtual pure returns (BlockHeader memory header) {		
	        assembly {
			// input should be a pointer to start of a calldata slice
			function decode_length(input, length) -> offset, strLen, isList {

				if iszero(length) { revert(0, 1) }

				let prefix := byte(0, calldataload(input))

				function getcd(start, len) -> val {
					mstore(0, 0)
					let dst := sub(32, len)
					calldatacopy(dst, start, len)
					val := mload(0)
					mstore(0, 0)
				}

				if lt(prefix, 0x80) {
					offset := 0
					strLen := 1
					isList := 0
					leave
				}

				if lt(prefix, 0xb8) {
					if iszero(gt(length, sub(prefix, 0x80))) { revert(0, 0xff) }
					strLen := sub(prefix, 0x80)
					offset := 1
					isList := 0
					leave
				}

				if lt(prefix, 0xc0) {
					if iszero(and(
						gt(length, sub(prefix, 0xb7)),
						gt(length, add(sub(prefix, 0xb7), getcd(add(input, 1), sub(prefix, 0xb7))))
					)) { revert(0, 0xff) }

				        let lenOfStrLen := sub(prefix, 0xb7)
					strLen := getcd(add(input, 1), lenOfStrLen)
					offset := add(1, lenOfStrLen)
					isList := 0
					leave
				}

				if lt(prefix, 0xf8) {
					if iszero(gt(length, sub(prefix, 0xc0))) { revert(0, 0xff) }
					// listLen
					strLen := sub(prefix, 0xc0)
					offset := 1
					isList := 1
					leave
				}

				if lt(prefix, 0x0100) {
					if iszero(and(
						gt(length, sub(prefix, 0xf7)),
						gt(length, add(sub(prefix, 0xf7), getcd(add(input, 1), sub(prefix, 0xf7))))
					)) { revert(0, 0xff) }

					let lenOfListLen := sub(prefix, 0xf7)
					// listLen
					strLen := getcd(add(input, 1), lenOfListLen)
					offset := add(1, lenOfListLen)
					isList := 1
					leave
				}

				revert(0, 2)
			}

			// Initialize rlp variables with the block's list
			let iptr := rlpHeader.offset
			let ilen := rlpHeader.length
			let offset,len,isList := decode_length(iptr, ilen)

			// There's only 1 list in the Ethereum block RLP encoding (the block itself)
			// If the first param isn't a list, revert
			switch isList
			case 0 { revert(0, 3) }

			// The returned offset + length refer to the list's payload
			// We pass those values to begin extracting block properties
			iptr := add(iptr, offset)
			ilen := len

			// bytes32 parentHash;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(header, sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// bytes32 uncleHash;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x20), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// address coinbase;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x40), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)
			
			// bytes32 root;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x60), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// bytes32 txHash;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x80), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// bytes32 receiptHash;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0xa0), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// bytes32[8] bloom;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(mload(add(header, 0xc0)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// uint256 difficulty;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0xe0), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

//			function write(iptr, len, dst_ptr, base_len) {
//				calldatacopy(add(dst_ptr, sub(base_len, len)), iptr, len)
//			}
 
			// uint256 number;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x100), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// uint256 gasLimit;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x120), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// uint256 gasUsed;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x140), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// uint256 time;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x160), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// bytes extra;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			let free := mload(0x40)
			mstore(add(header, 0x1e0), free)
			mstore(free, len)
			mstore(0x40, add(free, add(0x20, len)))
			calldatacopy(add(free, 0x20), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// bytes32 mixDigest;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x180), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// uint64 nonce;
			offset,len,isList := decode_length(iptr, ilen)
			if isList { revert(0, 4) }
			calldatacopy(add(add(header, 0x1a0), sub(0x20, len)), add(iptr, offset), len)
	                iptr := add(iptr, add(len, offset))
	                ilen := sub(ilen, len)

			// uint256 baseFee;
			// This might not exist on some chains and legacy blocks
			switch gt(iptr, add(rlpHeader.length, rlpHeader.offset))
			case 0 {
				offset,len,isList := decode_length(iptr, ilen)
				if isList { revert(0, 4) }
				calldatacopy(add(add(header, 0x1c0), sub(0x20, len)), add(iptr, offset), len)
		                iptr := add(iptr, add(len, offset))
		                ilen := sub(ilen, len)
			}
		}
	}

	function getSignedBlock(uint256 blockchainId, uint256 number) public view returns (bytes32 blockHash, BlockHeader memory blockHeader, SignedBlock memory signedBlock) {
		bytes32[] memory _blockHashes = blockHashes[blockchainId][number];
		require(_blockHashes.length != 0, '_blockHashes.length');
		blockHash = _blockHashes[0];
		for (uint256 i = 1; i < _blockHashes.length; i++) {
			if (_blockHashes[i] > blockHash) blockHash = _blockHashes[i];
		}
		SignedBlock storage _block = signedBlocks[blockHash];
		signedBlock.signatures = _block.signatures;
		signedBlock.creator = _block.creator;
		if (_isFuse(blockchainId)) {
			signedBlock.validators = _block.validators;
			signedBlock.cycleEnd = _block.cycleEnd;
		}
		blockHeader = blockHeaders[blockHash];
	}

	function _isValidator(address person) internal virtual returns (bool) {
		// TODO: better logic here
		return person == votingContract;
	}

	function _isNewBlock(bytes32 key) private view returns (bool) {
		return signedBlocks[key].signatures.length == 0;
	}

	function _isFuse(uint256 blockchainId) internal view virtual returns (bool) {
		// TODO better setup for this
		return blockchainId == 0x7a;
	}
}
