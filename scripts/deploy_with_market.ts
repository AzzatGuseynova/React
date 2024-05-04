import { deploy } from './ethers-lib'

(async function() {
    const accounts = await web3.eth.getAccounts(); // Получаем список аккаунтов
    const contractName = "Marketplace"; // Имя контракта
    const contractPath = `browser/contracts/${contractName}.sol:${contractName}`; // Путь к контракту в Remix

    const metadata = JSON.parse(await remix.call('fileManager', 'getFile', `artifacts/${contractPath}_metadata.json`));
    const contract = new web3.eth.Contract(metadata.output.abi);

    // Параметры конструктора контракта
    const deployedContract = await contract.deploy({
        data: metadata.output.evm.bytecode.object,
        arguments: ["NFT Marketplace", "NFTMP", "10000000000000000", "100000000000000000", "50000000000000000", 5, 86400]
    }).send({
        from: accounts[0],
        gas: 4700000,
        gasPrice: '100000000000' // 100 Gwei
    });

    console.log('Contract deployed at address:', deployedContract.options.address);
})();