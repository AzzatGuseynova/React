const Marketplace = artifacts.require("Marketplace");

contract("Marketplace", accounts => {
    const [admin, buyer, renter, unauthorized, referrer] = accounts;
    let marketplace;
    
    before(async () => {
        marketplace = await Marketplace.deployed();
    });

    describe("Initial Setup", () => {
        it("admin role should be assigned to the deployer", async () => {
            assert(await marketplace.hasRole(web3.utils.soliditySha3("ADMIN_ROLE"), admin), "Admin should have ADMIN_ROLE");
        });
    });

    describe("Product Management", () => {
        it("should allow admin to add a product", async () => {
            await marketplace.addProduct("Digital Art", web3.utils.toWei("1", "ether"), true, true, 3600, {from: admin});
            const product = await marketplace.products(0);
            assert.equal(product.name, "Digital Art", "Product name should be correctly set");
        });

        it("should not allow unauthorized users to add a product", async () => {
            try {
                await marketplace.addProduct("Fake Art", web3.utils.toWei("1", "ether"), true, false, 3600, {from: unauthorized});
                assert.fail("Unauthorized user added a product");
            } catch (error) {
                assert(error.message.includes("Caller is not an admin"), "Should revert with admin only message");
            }
        });

        it("should reject product additions below minimum price requirements", async () => {
            await assert.reverts(
                marketplace.addProduct("Cheap Art", web3.utils.toWei("0.01", "ether"), true, false, 3600, {from: admin}),
                "Price too low."
            );
        });
    });

    describe("Buying and Renting Operations", () => {
        before(async () => {
            await marketplace.addProduct("Expensive Art", web3.utils.toWei("5", "ether"), true, true, 86400, {from: admin});
        });

        it("should allow a user to buy a product", async () => {
            await marketplace.buyProduct(1, referrer, {from: buyer, value: web3.utils.toWei("5", "ether")});
            const product = await marketplace.products(1);
            assert.equal(product.owner, buyer, "Buyer should now own the product");
        });

        it("should transfer funds and handle fees correctly on purchase", async () => {
            const initialBalance = web3.utils.toBN(await web3.eth.getBalance(admin));
            await marketplace.buyProduct(2, referrer, {from: buyer, value: web3.utils.toWei("5", "ether")});
            const newBalance = web3.utils.toBN(await web3.eth.getBalance(admin));
            assert(newBalance.gt(initialBalance), "Admin should have received the transaction fees");
        });

        it("should allow a user to rent a product", async () => {
            await marketplace.rentProduct(1, referrer, {from: renter, value: web3.utils.toWei("2.5", "ether")});
            const product = await marketplace.products(1);
            assert.equal(product.renter, renter, "Renter should now be renting the product");
        });

        it("should prevent renting an already rented product", async () => {
            await assert.reverts(
                marketplace.rentProduct(1, referrer, {from: unauthorized, value: web3.utils.toWei("2.5", "ether")}),
                "Product already rented."
            );
        });
    });

    describe("Referral and Financial Management", () => {
        it("should correctly apply referral bonuses", async () => {
            const initialBalance = web3.utils.toBN(await web3.eth.getBalance(referrer));
            await marketplace.buyProduct(3, referrer, {from: buyer, value: web3.utils.toWei("5", "ether")});
            const newBalance = web3.utils.toBN(await web3.eth.getBalance(referrer));
            assert(newBalance.gt(initialBalance), "Referrer should receive a bonus");
        });

        it("should allow only admin to withdraw funds", async () => {
            try {
                await marketplace.withdrawFunds({from: unauthorized});
                assert.fail("Unauthorized user managed to withdraw funds");
            } catch (error) {
                assert(error.message.includes("Caller is not an admin"), "Should revert with admin only message");
            }
        });
    });
});
