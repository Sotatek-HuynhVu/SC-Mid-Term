// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SwapContract is Ownable, ReentrancyGuard {
    enum SwapStatus {
        Pending,
        Approved,
        Rejected,
        Cancelled
    }

    struct SwapRequest {
        address requester;
        address counterparty;
        uint256 amount;
        SwapStatus status;
    }

    mapping(uint256 => SwapRequest) public swapRequests;
    mapping(address => bool) public isAuthorized;
    address public treasury;
    uint256 public transactionFee;

    event SwapRequestCreated(
        uint256 indexed requestId,
        address indexed requester,
        uint256 amount
    );
    event SwapRequestStatusChanged(
        uint256 indexed requestId,
        SwapStatus status
    );
    event TreasuryUpdated(address indexed newTreasury);
    event TransactionFeeUpdated(uint256 newFee);

    constructor(address _treasury) Ownable(msg.sender) {
        treasury = _treasury;
        isAuthorized[msg.sender] = true;
    }

    function createSwapRequest(
        uint256 _amount,
        address _counterparty
    ) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            _counterparty != address(0),
            "Counterparty address cannot be zero"
        );

        uint256 requestId = uint256(
            keccak256(
                abi.encodePacked(msg.sender, _counterparty, block.timestamp)
            )
        );
        require(
            swapRequests[requestId].requester == address(0),
            "Swap request already exists"
        );

        swapRequests[requestId] = SwapRequest({
            requester: msg.sender,
            counterparty: _counterparty,
            amount: _amount,
            status: SwapStatus.Pending
        });

        emit SwapRequestCreated(requestId, msg.sender, _amount);
    }

    function approveSwapRequest(uint256 _requestId) external nonReentrant {
        SwapRequest storage request = swapRequests[_requestId];
        require(
            request.status == SwapStatus.Pending,
            "Swap request status is not Pending"
        );
        require(
            msg.sender == request.counterparty,
            "Only counterparty can approve"
        );

        request.status = SwapStatus.Approved;
        uint256 fee = (request.amount * transactionFee) / 10000;
        uint256 amountToTransfer = request.amount - fee;

        payable(treasury).transfer(fee);
        payable(request.requester).transfer(amountToTransfer);

        emit SwapRequestStatusChanged(_requestId, SwapStatus.Approved);
    }

    function rejectSwapRequest(uint256 _requestId) external nonReentrant {
        SwapRequest storage request = swapRequests[_requestId];
        require(
            request.status == SwapStatus.Pending,
            "Swap request status is not Pending"
        );
        require(
            msg.sender == request.counterparty ||
                msg.sender == request.requester,
            "Not authorized to reject"
        );

        request.status = SwapStatus.Rejected;

        if (msg.sender == request.counterparty) {
            payable(request.requester).transfer(request.amount);
        }

        emit SwapRequestStatusChanged(_requestId, SwapStatus.Rejected);
    }

    function cancelSwapRequest(uint256 _requestId) external nonReentrant {
        SwapRequest storage request = swapRequests[_requestId];
        require(
            request.status == SwapStatus.Pending,
            "Swap request status is not Pending"
        );
        require(msg.sender == request.requester, "Only requester can cancel");

        request.status = SwapStatus.Cancelled;
        payable(request.requester).transfer(request.amount);

        emit SwapRequestStatusChanged(_requestId, SwapStatus.Cancelled);
    }

    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Treasury address cannot be zero");
        treasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

    function updateTransactionFee(uint256 _newFee) external onlyOwner {
        transactionFee = _newFee;
        emit TransactionFeeUpdated(_newFee);
    }

    function authorize(address _account, bool _status) external onlyOwner {
        isAuthorized[_account] = _status;
    }

    receive() external payable {}
    
    fallback() external payable {}
}

contract SwapContractProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _admin,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(_logic, _admin, _data) {
        require(_data.length == 0, "Invalid data length");
        _data = abi.encodeWithSignature("constructor(address)", msg.sender);
    }
}
