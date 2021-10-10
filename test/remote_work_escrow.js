const RemoteWorkEscrow = artifacts.require("RemoteWorkEscrow");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("RemoteWorkEscrow", function (accounts) {
  let remoteWorkEscrow;
  let amount = web3.utils.toWei("1", "ether");
  let depositInEther = web3.utils.fromWei(amount)
  let [owner, arbiter, agent] = accounts;

  beforeEach(async function(){
    remoteWorkEscrow = await RemoteWorkEscrow.new(arbiter, {from: owner});
  });
  it("should assert true", async function () {
    
    return assert.isTrue(true);
  });
  it("should allow for a new task to be added", async function(){
    await remoteWorkEscrow.addTask("Sew a thread",{from: owner, value: amount});
    const result = await remoteWorkEscrow.getTask(1);
    assert.equal(result._taskName,"Sew a thread");    
  });
  it("should FAIL if ether is not added", async function(){
    try {
      await remoteWorkEscrow.addTask("Sew a thread",{from: owner});
    } catch (err) {
      assert(err.message.includes("You must add a task and send ether"));
      return;
    }
    assert(false);
  });
  it("should get contract balance", async function(){
    const addressOf = remoteWorkEscrow.address;
    await remoteWorkEscrow.addTask("Sew a thread",{from: owner, value: amount});
    const balanceOf = await web3.eth.getBalance(addressOf);
    assert.equal(balanceOf, amount);
  });
  it("should allow for task to be deleted if uninitiated", async function(){
    await remoteWorkEscrow.addTask("Sew a thread",{from: owner, value: amount});
    const result = await remoteWorkEscrow.deleteTask(1);
    try {
      await remoteWorkEscrow.getTask(1);
    } catch (err) {
      assert(err.message.includes("Task does not exist!"));
      return;
    }
    assert(false);   
  });
  it("should allow for another to accept task", async function(){
    await remoteWorkEscrow.addTask("Test New Function",{from: owner, value: amount});
    await remoteWorkEscrow.acceptTask(1, {from: agent});
    const result = await remoteWorkEscrow.AgentToTask(1);
    assert.equal(result,agent);
  });
  it("should allow for agent to abandon task", async function(){
    await remoteWorkEscrow.addTask("Test New Function",{from: owner, value: amount});
    await remoteWorkEscrow.acceptTask(1, {from: agent});
    await remoteWorkEscrow.abandonTask(1, {from: agent});
    const result = await remoteWorkEscrow.getTask(1);
    assert.equal(result.status.toString(), RemoteWorkEscrow.TaskState.Uninitiated);    
  });
  it("should allow the owner to accept completion and pay agent", async function(){
    await remoteWorkEscrow.addTask("Test New Function",{from: owner, value: amount});
    await remoteWorkEscrow.acceptTask(1, {from: agent});

    const raw1 = await web3.eth.getBalance(agent);
    const balanceBefore = await web3.utils.fromWei(raw1)
    await remoteWorkEscrow.taskSubmitted(1, {from: agent});
    await remoteWorkEscrow.acceptCompletion(1, {from: owner});
    const raw2 = await web3.eth.getBalance(agent);

    const balanceAfter = await web3.utils.fromWei(raw2);
    const diff = balanceAfter - balanceBefore;
      
    assert.equal(Math.round(diff),depositInEther);
  });
  it("should not allow a non-owner to accept completion", async function(){
    await remoteWorkEscrow.addTask("Test New Function",{from: owner, value: amount});
    await remoteWorkEscrow.acceptTask(1, {from: agent});
    
    await remoteWorkEscrow.taskSubmitted(1, {from: agent});
    try {
      await remoteWorkEscrow.acceptCompletion(1, {from: agent});
    } catch (err) {
      assert(err.message.includes("You are not the Owner!"));
      return;
    }
    assert(false);    
  });
  it("should allow the arbiter refund Beneficiary", async function(){
    await remoteWorkEscrow.addTask("Test New Function",{from: owner, value: amount});
    const raw1 = await web3.eth.getBalance(owner);
    let balanceBefore = await web3.utils.fromWei(raw1);
    balanceBefore = Math.round(balanceBefore);
    await remoteWorkEscrow.refundBeneficiary(1,{from: arbiter})

    let balanceAfter = await web3.eth.getBalance(owner);
    balanceAfter = await web3.utils.fromWei(balanceAfter);
    balanceAfter = Math.round(balanceAfter);

    assert.equal(balanceAfter, balanceBefore+1);

  });
  it("should allow the arbiter pay the Agent", async function(){
    await remoteWorkEscrow.addTask("Test New Function",{from: owner, value: amount});
    await remoteWorkEscrow.acceptTask(1, {from: agent});
    let raw = await web3.eth.getBalance(agent);
    let raw1  = await web3.utils.fromWei(raw)
    const balanceBefore = Math.round(raw1);

    await remoteWorkEscrow.taskSubmitted(1, {from: agent});
    await remoteWorkEscrow.raiseDispute(1, {from: agent})
    await remoteWorkEscrow.payAgent(1, {from: arbiter});
    let raw2 = await web3.eth.getBalance(agent);
    let raw3 = await web3.utils.fromWei(raw2);
    balanceAfter = Math.round(raw3);
    
    assert.equal(balanceAfter, balanceBefore+1);

  });
  
});
