// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RemoteWorkEscrow{
    
    //define the events
    event newTask(address indexed sender, uint id, string name, uint amount);
    event closeTask(address indexed sender, address beneficiary, uint id, string name, uint amount);
    event deletedTask(address indexed sender, uint id, string name, uint amount);
    event acceptedTask(address indexed sender, uint id, string name, uint amount);
    event submittedTask(address indexed sender, uint id, string name, uint amount);
    event abandonedTask(address indexed sender, uint id, string name, uint amount);
    event disputedTask(address indexed sender,address resolver, uint id, string name, uint amount);
    event beneficiaryRefunded(address indexed sender, uint id, string name, uint amount);
    event toggleDisputeMarker(address indexed sender, uint id, string name, bool prev, bool current);

    /**Declare all the variables and data types used in the contract.
     * The TaskToAmount stores that amount assigned to each Task
     * The TaskState stores the state of completion of the task. */
    
    address public owner; //deployer of contract
    address public arbiter; //arbitrator, supplied by contract
    uint taskId; //unique identifier for each task
    uint public taskCounter; //counter for number of tasks created
    
    

    //define the state of the Task
    enum TaskState {Uninitiated, Initiated, UnderReview, Completed}
    
    //create a data type to store job requests
    struct Task{
        uint TaskId;
        string TaskName;
        uint256 amount;
        TaskState _state;
        bool dispute; //defines whether there is a payment dispute on the task, can only be made true by agent
    } 
    
    //store the Job Id and the amount for the Job
    mapping(uint =>  Task) Tasks;
    mapping(uint => address) public AgentToTask;
    
    //define the access controls for the contract
    modifier onlyOwner(){
        require(msg.sender == owner, "You are not the Owner!");
        _;
    }
    
    modifier onlyArbiter(){
        require(msg.sender == arbiter, "You are not authorized!");
        _;
    }
    
    modifier onlyAgent(){
        require(msg.sender != arbiter && msg.sender != owner, "You are not authorized!");
        _;
    }
    modifier taskExists(uint _taskId){
        require(Tasks[_taskId].amount != 0, "Task does not exist!");
        _;
    }
    
    constructor(address _arbiter){
        owner = msg.sender;
        arbiter = _arbiter;
        taskId = 1;
    }
    
    /** Owners functions
    - addTask: This function adds a new task, and keeps track of tasks created.
    - getContract Balance: This function is available to all parties.
    - getTask: The getter function for viewing a task by its unique identifier.
    - acceptCompletion: Allows the owner accept that a task is completed, and trasnfers funds to the Agent.
    - deleteTask: Allows the pwner delete tasks that are not under dispute.*/
    function addTask(string calldata _taskName) payable external onlyOwner {
        require(bytes(_taskName).length > 0 && msg.value != 0, "You must add a task and send ether");
        TaskState state = TaskState.Uninitiated;
        Tasks[taskId] = Task(taskId, _taskName, msg.value, state, false);
        taskId++;
        taskCounter++;
        emit newTask(msg.sender, Tasks[taskId].TaskId, Tasks[taskId].TaskName, Tasks[taskId].amount);
    }
    
    function getContractBalance() view external returns(uint256) {
        return address(this).balance;
    }
    
    function getTask(uint _Id) view external taskExists(_Id) returns(uint _taskId,string memory _taskName, uint _taskAmount, TaskState status, bool UnderDispute) {
        Task storage taskInstance = Tasks[_Id];
        return(taskInstance.TaskId, taskInstance.TaskName, taskInstance.amount, taskInstance._state, taskInstance.dispute);
    }
    
    function acceptCompletion(uint _taskId) public onlyOwner taskExists(_taskId) {
        Tasks[_taskId]._state = TaskState.Completed;
        uint holder = Tasks[_taskId].amount;
        Tasks[_taskId].amount = 0;
        payable(AgentToTask[_taskId]).transfer(holder);
        emit closeTask(msg.sender, AgentToTask[_taskId], Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
        delete Tasks[_taskId];
        taskCounter--;
        delete AgentToTask[_taskId];
        
    }
    
    function deleteTask(uint _taskId) public onlyOwner taskExists(_taskId) {
        require(Tasks[_taskId]._state == TaskState.Uninitiated, "Contact Arbiter!" );
        require(Tasks[_taskId].dispute == false, "Contact Arbiter for dispute resolution");
        payable(owner).transfer(Tasks[_taskId].amount);
        emit deletedTask(msg.sender, Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
        delete Tasks[_taskId];
        taskCounter--;
        delete AgentToTask[_taskId];
    }
    
    /**Agent's functions
    - acceptTask: Allows the agent to accept a job.
    - taskSubmitted: Allows the agent to declare a task has been submitted.
    - abandonTask: Allows the agent to reject a task, after initially accepting it.
    - raiseDispute: Allows the agent to raise a dispute on a Task, this prevents the owner from 
                    taking advantage of the Agent  */
    function acceptTask(uint _taskId) external onlyAgent taskExists(_taskId) {
        Tasks[_taskId]._state = TaskState.Initiated;
        AgentToTask[_taskId] = msg.sender;
        emit acceptedTask(AgentToTask[_taskId], Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
    }
    
    function taskSubmitted(uint _taskId) external onlyAgent taskExists(_taskId) {
        require(msg.sender == AgentToTask[_taskId], "You cannot submit for this task");
        Tasks[_taskId]._state = TaskState.UnderReview;
        emit submittedTask(AgentToTask[_taskId], Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
    }
    
    function abandonTask(uint _taskId) external onlyAgent taskExists(_taskId) {
        Tasks[_taskId]._state = TaskState.Uninitiated;
        emit abandonedTask(AgentToTask[_taskId], Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
        delete AgentToTask[_taskId];
    }
    
    function raiseDispute(uint _taskId) external onlyAgent taskExists(_taskId) {
        Tasks[_taskId].dispute = true;
        emit disputedTask(AgentToTask[_taskId], arbiter, Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
    }
    
    /** Arbiter's functions:
    - refundBeneficary: This function allows the Arbiter refund the owner of the contract
                        for a specific task, provided the task is not under dispute. 
    - payAgent: This function allows the Arbiter pay the agent, given that the dispute has
                been resolved in favour of the Agent. */
    function refundBeneficiary(uint _taskId) external onlyArbiter {
        require(Tasks[_taskId].dispute == false, "Requires Dispute resolution!");
        payable(owner).transfer(Tasks[_taskId].amount);
        Tasks[_taskId]._state = TaskState.Uninitiated;
        emit beneficiaryRefunded(msg.sender, Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, Tasks[_taskId].amount);
        delete Tasks[_taskId];
        taskCounter--;
        delete AgentToTask[_taskId];
    }
    
    function payAgent(uint _taskId) external onlyArbiter {
        require(Tasks[_taskId].dispute == true, "Refund beneficiary instead!");
        payable(AgentToTask[_taskId]).transfer(Tasks[_taskId].amount);
        Tasks[_taskId]._state = TaskState.Uninitiated;
        delete Tasks[_taskId];
        taskCounter--;
        delete AgentToTask[_taskId];
    }

    function toggleDispute(uint _taskId) external onlyArbiter {
        bool prev = Tasks[_taskId].dispute;
        Tasks[_taskId].dispute = !Tasks[_taskId].dispute;
        emit toggleDisputeMarker(msg.sender, Tasks[_taskId].TaskId, Tasks[_taskId].TaskName, prev, Tasks[_taskId].dispute);
        

    }
    
    
}