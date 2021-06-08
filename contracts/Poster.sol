pragma solidity  ^0.4.26;
/**
 * @title Poster
 * @dev Maintain basic information of records
 */
import "./Owner.sol";
contract Poster is Owner {

    struct Stake {
        uint value;         // stake amount
        uint calcStart;     // block.number for calculate coins-day
    }

    struct Record {
        string info;        // infomation of this record
        address author;     // author
        uint deposit;       // deposit
        uint start;         // block.number of new this record
        uint update;        // block.number of last information update
        mapping(address => Stake) stakes;    // user -> stake , users for support this record
        address[] users;    // users support this record
    }

    uint public maxDepositLen = 3600 * 24;  // can not modify by anyone
    uint public minDepositVal = 0;          //
    uint public minDepositLen = 3600;       //
    uint public termination   = 0;          //
    uint public nextRecordID  = 0;          //
    string public notice      = "";         //
    mapping(uint => Record) public records; // recordID -> record

    event Terminate(address indexed owner);
    event AddRecord(address indexed author, string info, uint deposit);
    
    modifier isValid() {
        require(termination == 0, "Contract is expired");
        _;
    }
    
    function setMinDeposit(uint _minDepositVal, uint _minDepositLen) public isOwner isValid {
        require(_minDepositLen <= maxDepositLen, "Deposit length can not longer than maxDepositLen");
        minDepositVal = _minDepositVal;
        minDepositLen = _minDepositLen;
    }
    
    function terminateSys() public isOwner isValid{
        termination = block.number;
        emit Terminate(msg.sender);
    }
    
    function setNotice(string _notice) public isOwner {
        notice = _notice;
    }
    
    function addRecord(string _info) public payable isValid {
        require(msg.value >= minDepositVal);
        records[nextRecordID] = Record({
            info: _info,
            author: msg.sender,
            deposit: msg.value,
            start: block.number,
            update: block.number,
            users: new address[](0)
        });
        nextRecordID += 1;
        emit AddRecord(msg.sender, _info, msg.value);
    }
    
    function updateRecord(uint _recordID, string _info) public payable isValid{
        require(records[_recordID].author == msg.sender, "Caller is not author");
        records[_recordID].info = _info;
        records[_recordID].deposit += msg.value;
        records[_recordID].update = block.number;
    }

    function delRecord(uint _recordID) public {
        require(records[_recordID].author == msg.sender, "Caller is not author");
        require(block.number - records[_recordID].update > minDepositLen, "Deposit length should longer than minDepositLen");
        uint deposit = records[_recordID].deposit;
        records[_recordID].deposit = 0;
        records[_recordID].author = address(0);
        records[_recordID].info = "";
        records[_recordID].update = block.number;
        require(msg.sender.send(deposit));
    }

    function propRecord(uint _recordID) public payable isValid{
        require(_recordID < nextRecordID, "ID is not exist");
        require(records[_recordID].author != address(0), "Record is not valid");
        require(msg.value > 0, "value is missing");
        Stake storage s = records[_recordID].stakes[msg.sender];
        if (s.value > 0) {
            s.calcStart = block.number - ((block.number - s.calcStart) * (s.value / ( s.value + msg.value)));
        } else {
            s.calcStart = block.number;
            records[_recordID].users.push(msg.sender);
        }
        s.value += msg.value;
    }
    
    function fadeRecord(uint _recordID, uint _val) public {
        require(_recordID < nextRecordID, "ID is not exist");
        Stake storage s = records[_recordID].stakes[msg.sender];
        require(s.value >= _val, "Stake for your address is not enough");
        if (s.value == _val) {
            delete records[_recordID].stakes[msg.sender];
            // remove user from users array
            bool moveForward = false;
            for (uint i = 0; i< records[_recordID].users.length-1; i++){
                if (records[_recordID].users[i] == msg.sender) {
                    moveForward = true;
                    continue;
                }
                if (moveForward) {
                    records[_recordID].users[i] = records[_recordID].users[i+1];
                } else {
                    records[_recordID].users[i] = records[_recordID].users[i];
                }
            }
            delete records[_recordID].users[records[_recordID].users.length-1];
            records[_recordID].users.length--;
        } else {
            s.value -= _val;
        }
        require(msg.sender.send(_val));
    }
    
    function getRecord(uint _recordID) external view returns (string, address, uint, uint, uint, uint, address[]) {
        require(_recordID < nextRecordID, "ID is not exist");
        uint coinsDay = 0;
        Record memory r = records[_recordID];
        for (uint i = 0; i < records[_recordID].users.length; i++) {
            Stake memory s = records[_recordID].stakes[records[_recordID].users[i]];
            coinsDay += s.value * (block.number - s.calcStart);
        }
        return (r.info, r.author, r.deposit, r.start, r.update, coinsDay, r.users);
    }
    
    function getStake(uint _recordID, address _user) external view returns (uint, uint) {
        require(_recordID < nextRecordID, "ID is not exist");
        Stake memory s = records[_recordID].stakes[_user];
        return (s.value, s.calcStart);
    }
    
}
