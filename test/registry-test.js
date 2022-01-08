const { expect, use } = require("chai");
const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");

use(solidity)

describe('BlockHeaderRegistry', async () => {
	let BlockHeaderRegistry
	let blockHeaderRegistry
	let signers
	before(async() => {
		signers = await ethers.getSigners();
		BlockHeaderRegistry = await ethers.getContractFactory('BlockHeaderRegistryMock')
		blockHeaderRegistry = await BlockHeaderRegistry.connect(signers[0]).deploy()
		await blockHeaderRegistry.deployed()
	})
	describe('Blockchains', () => {
		it('Should add a new blockchain', async () => {
			const signer = signers[0]
			const tx = await blockHeaderRegistry.connect(signer).addBlockchain(1337, 'http://localhost:8545')
			const rx = await tx.wait()
			expect(rx.status).to.equal(1)
		})
		it('Should not add a new blockchain from a random caller', async () => {
			const signer = signers[1]
			await expect(blockHeaderRegistry.connect(signer).addBlockchain(1337, 'http://localhost:8545')).to.be.revertedWith('onlyVoting');
		})
	})
	describe('Rlp decoding block', () => {
		it('Should properly decode an rlp encoded block', async  () => {
                        const header = {
                                'parentHash':'0x1e77d8f1267348b516ebc4f4da1e2aa59f85f0cbd853949500ffac8bfc38ba14',
                                'uncleHash':'0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
                                'coinbase':'0x2a65Aca4D5fC5B5C859090a6c34d164135398226',
                                'root':'0x0b5e4386680f43c224c5c037efc0b645c8e1c3f6b30da0eec07272b4e6f8cd89',
                                'txHash':'0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
                                'receiptHash':'0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
				'bloom': '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
                                'difficulty':ethers.utils.hexlify(6022643743806),
                                'number':ethers.utils.hexlify(400000),
                                'gasLimit':ethers.utils.hexlify(3141592),
                                'gasUsed': 0,
                                'time': ethers.utils.hexlify(1445130204),
                                'extra':'0xd583010202844765746885676f312e35856c696e7578',
				'mixDigest':'0x3fbea7af642a4e20cd93a945a1f5e23bd72fc5261153e09102cf718980aeff38',
                                'nonce':'0x6af23caae95692ef',
                                'baseFee': 0,
                        }
			const rlpHeader = ethers.utils.RLP.encode(Object.values(header).map(v => v == 0 ? '0x' : v))
			const decoded = await blockHeaderRegistry.parseBlock(rlpHeader)
			for (const [key, value] of Object.entries(header)) {
				// For now this value is kept as 8 * 32 bytes
				if (key == 'bloom') expect('0x' + decoded[key].map(v => v.substr(2)).join('')).to.equal(value)
				else expect(decoded[key]).to.equal(value)
			}

		})
	})
	describe('Adding signed blocks', () => {
		it('Should add a standard EVM signed block', async () => {
			const signer = signers[0]
			const header = {
				'ParentHash':'0x1e77d8f1267348b516ebc4f4da1e2aa59f85f0cbd853949500ffac8bfc38ba14',
				'UncleHash':'0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
				'Coinbase':'0x2a65Aca4D5fC5B5C859090a6c34d164135398226',
				'Root':'0x0b5e4386680f43c224c5c037efc0b645c8e1c3f6b30da0eec07272b4e6f8cd89',
				'TxHash':'0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
				'ReceiptHash':'0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421',
				'Bloom':'0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
				'Difficulty':ethers.utils.hexlify(6022643743806),
				'Number':ethers.utils.hexlify(400000),
				'GasLimit':ethers.utils.hexlify(3141592),
				'GasUsed': '0x', //(0).toString(16),
				'Time': ethers.utils.hexlify(1445130204),
				'Extra':'0xd583010202844765746885676f312e35856c696e7578',
				'MixDigest':'0x3fbea7af642a4e20cd93a945a1f5e23bd72fc5261153e09102cf718980aeff38',
				'Nonce':'0x6af23caae95692ef',
//				'BaseFee': 0
			}

			const values = [['ParentHash','0x1e77d8f1267348b516ebc4f4da1e2aa59f85f0cbd853949500ffac8bfc38ba14'],
['UncleHash','0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347'],
['Coinbase','0x2a65Aca4D5fC5B5C859090a6c34d164135398226'],
['Root','0x0b5e4386680f43c224c5c037efc0b645c8e1c3f6b30da0eec07272b4e6f8cd89'],
['TxHash','0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421'],
['ReceiptHash','0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421'],
['Bloom','0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'],
['Difficulty',ethers.utils.hexlify(6022643743806)],
['Number',ethers.utils.hexlify(400000)],
['GasLimit',ethers.utils.hexlify(3141592)],
['GasUsed', '0x' ],//(0).toString(16)],
['Time', ethers.utils.hexlify(1445130204)],
['Extra','0xd583010202844765746885676f312e35856c696e7578'],
['MixDigest','0x3fbea7af642a4e20cd93a945a1f5e23bd72fc5261153e09102cf718980aeff38'],
['Nonce','0x6af23caae95692ef']]
			const rlpHeader = ethers.utils.RLP.encode(Object.values(header).map((v,i) => {
				if (v!= values[i][1]) throw new Error(i, values[i])
				return v === 0 ? '0x' : v
			}))
			const blockHash = "0x5d15649e25d8f3e2c0374946078539d200710afc977cdfc6a977bd23f20fa8e8"
			expect(blockHash).to.equal(ethers.utils.keccak256(rlpHeader))
			const { _vs:vs, r } = ethers.utils.splitSignature(await signer.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(rlpHeader))))
			const tx = await blockHeaderRegistry.connect(signer).addSignedBlocks([
				[
					rlpHeader,
					[ r, vs ],
					1,
					blockHash,
					0, // cycleEnd
					[] // validators
				]
			])
			const rx = await tx.wait()
			expect(rx.status).to.equal(1)
		})
	})
})
