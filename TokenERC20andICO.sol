//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;
 
// EIP-20: EC-20 Token Standard

interface ERC20Interface {
    
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint value) external returns (bool success);

    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

//The Crypto Token Contract
contract Cryptos is ERC20Interface {
    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint public decimals = 0; //18
    uint public override totalSupply;

    address public founder;
    mapping(address => uint) public balances;

    mapping(address => mapping(address => uint)) allowed;

    constructor(){
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenOwner) public view override returns (uint balance){
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public override virtual returns(bool success){
        require(balances[msg.sender] >= tokens);

        balances[to] += tokens;
        balances[msg.sender] -= tokens;
        emit Transfer(msg.sender, to, tokens);

        return true;
    }

    function allowance(address tokenOwner, address spender) view public override returns(uint){
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public override returns (bool success){
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens;
        
        emit Approval(msg.sender, spender, tokens);
        return true;
        
    }

    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success){
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);

        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;

        emit Transfer(from, to, tokens);
        return true;
    }
}

// The ICO contract
contract CryptosICO is Cryptos{
    address public admin;
    address payable public deposit;
    uint tokenPrice = 0.001 ether;                        // 1ETH = 1000 CRPT, 1CRPT = 0.001 ETH
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp;              //start ICO
    uint public saleEnd = block.timestamp + 604800;       // ICO finisches in one week
   
    uint public tokenTradeStart = saleEnd + 604800;       // transferable in a week after saleEnd
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State {beforeStart, running, afterEnd, halted}   //ICO states
    State public icoState;

    constructor(address payable _deposit){
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin);
        _;
    }

    // emergency stop
    function halt() public onlyAdmin{       
        icoState = State.halted;
    }

    function resume() public onlyAdmin{
        icoState = State.running;
    }

    function changeDepositAddress(address payable newDeposit) public onlyAdmin{
        deposit = newDeposit;
    }

    function getCurrentState() public view returns(State){
        if(icoState == State.halted){
            return State.halted;
        }else if (block.timestamp < saleStart){
            return State.beforeStart;
        }else if(block.timestamp >= saleStart && block.timestamp <=saleEnd){
            return State.running;
        }else{
            return State.afterEnd;
        }        
    }

    event Invest(address investor, uint value, uint tokens);

    // function called when sending eth to the contract
    function invest() payable public returns(bool){
        icoState = getCurrentState();
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);

        uint tokens = msg.value / tokenPrice;

        // adding tokens ti the investor's balance from the founder's balance
        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        
        // transfering the value sent to the ICO to the deposit address 
        deposit.transfer(msg.value);
        
        emit Invest(msg.sender, msg.value, tokens);

        return true;
    }

    // this function is called automatically when someone sends ETH to the contract's address
    receive() payable external{
        invest();
    }

    //the token will be transferable only after token trade start
    function transfer(address to, uint tokens) public override returns(bool success){
        require(block.timestamp > tokenTradeStart);

        //calling the transfer function of the base contract
        Cryptos.transfer(to, tokens);
        return true;
    }

    // the token will be transferable only after token trade start
    function transferFrom(address from, address to, uint tokens) public override returns (bool success){
        require(block.timestamp > tokenTradeStart);

        //calling the transfer function of the base contract
        Cryptos.transferFrom(from, to, tokens);
        return true;
    }
    
    // burning unsold tokens
    function burn() public returns(bool){     
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;
        return true;
    }
}

   
