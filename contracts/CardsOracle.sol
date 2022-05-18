// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IOracle.sol";

contract CardOracle is IOracle {

    address public owner;
    uint256 public fee;
    uint32 public requestId;
    bool public stopped;
    mapping(uint32 => Request) public idToRequest;

    event OracleRequest(uint32, bool, address, uint256); 
    event OracleFulfillment(uint32, bytes2[], address, uint256); 
    event Log(bytes);

    modifier onlyOwner {
      require(msg.sender == owner, "Sender is not owner");
      _;
    }

    modifier notStopped {
      require(!stopped, "Oracle is stopped");
      _;
    }

    constructor() {
        owner = msg.sender;
        stopped = false;
        fee = 0.001 * 10 ** 18; // 0.001 ETH
    }

    function receiveRequest(Request calldata _request) external payable notStopped returns (uint32){
        require(msg.value >= fee, "Please send more ETH");
        require(_request.nrOfCards > 0 && _request.cbClient != address(0) && _request.cbSelector != bytes4(0) && !_request.fulfilled, "Input data missing");
        
        idToRequest[requestId] = _request;
        emit OracleRequest(requestId, _request.shuffle, msg.sender, block.timestamp); 
        return requestId++;
    }

    function fulfillRequest(uint32 _requestId, bytes2[] calldata _cards) notStopped onlyOwner external {
        Request storage request = idToRequest[_requestId];

        require(request.cbClient != address(0), "No request with this id found");
        require(_cards.length == request.nrOfCards, "Incorrect number of cards");
        require(!request.fulfilled, "Request is already fulfilled");

        request.fulfilled = true;

        emit OracleFulfillment(_requestId, _cards, msg.sender, block.timestamp);
        (bool success, ) = request.cbClient.call(abi.encodeWithSelector(request.cbSelector, _requestId, _cards));
        require(success, "Couldn't fulfill request");
    }

    function toggleState() public onlyOwner {
        stopped = !stopped;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function withdraw(address payable _to) external onlyOwner {
        (bool success,) = _to.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
}