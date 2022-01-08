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
		uint64 nonce;
		// uint256 baseFee;
	}

	struct Block {
		BlockHeader header;
		bytes rlpHeader;
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
	mapping(bytes32 => bytes) rlpHeaders;

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

	function _hashBlock(BlockHeader memory header) internal virtual returns (bytes32 blockHash) {
		bytes.concat(
			hex'a0', header.parentHash,
			hex'a0', header.uncleHash,
			hex'94', header.coinbase,
			hex'a0', header.root,
			hex'a0', header.txHash,
			hex'a0', header.receiptHash,
			hex'b90100', header.bloom,
			hex'
		);
		encoded.push(hex'0x80')
	library Rlp {
		function encode(bytes32 self) returns (bytes memory encoded) {
			assembly {
				mstore(encoded, 0xa0)
				mstore(add(encoded, 0x20), self)
			}
		}
		function encode(uint256 self) returns (bytes memory encoded) {
			assembly {
				mstore(encoded, 0xa0)
				mstore(add(encoded, 1), self)
			}
		}
		function encode(address self) returns (bytes memory encoded) {
			assembly {
				mstore(encoded, shl(88, xor(0x940000000000000000000000000000000000000000, self)))
			}
		}

		function encode(uint64 self) returns (bytes memory encoded) {
			if (self < 0x01) { assembly { mstore(encoded, 0x80) } }
			if (self < 0x0100) { assembly { mstore(encoded, xor(0x81, bytes1())) } }
			if (self < 0x0100)
			// BE-align the LE int
			bytes32(bytes8(self)) * 
			assembly {
				
			}
			self * ''
			for (uint8 i; i < 8; i ++) {
				if (self ^ (256**(8 - i))-1) {
					assembly {
						mstore(encoded, xor(add(0x80, i), shl(mul(8, i), self)))
						mstore(add(encoded, 1), self)
					}
				}
			}
			assembly {
				mstore(0x20, self)
				mstore(encoded, shl(192, xor(0x860000000000000000, self)))
				mstore(encoadd(encoded, 1), self)
			}
		}
		function encode(bytes self) returns (bytes memory encoded) {
			assembly {
				mstore(encoded, 0xa0)
				mstore(add(encoded, 0x20), self)
			}
		}
	}

	function rlp_encode():
    if isinstance(input,str):
        if len(input) == 1 and ord(input) < 0x80: return input
        else: return encode_length(len(input), 0x80) + input
    elif isinstance(input,list):
        output = ''
        for item in input: output += rlp_encode(item)
        return encode_length(len(output), 0xc0) + output

def encode_length(L,offset):
    if L < 56:
         return chr(L + offset)
    elif L < 256**8:
         BL = to_binary(L)
         return chr(len(BL) + offset + 55) + BL
    else:
         raise Exception("input too long")

def to_binary(x):
    if x == 0:
        return ''
    else:
        return to_binary(int(x / 256)) + chr(x % 256)
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
