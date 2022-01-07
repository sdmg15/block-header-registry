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
		BlockHeaderRegistry = await ethers.getContractFactory('BlockHeaderRegistry')
		blockHeaderRegistry = await BlockHeaderRegistry.deploy('0x0000000000000000000000000000000000000000')
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
})
