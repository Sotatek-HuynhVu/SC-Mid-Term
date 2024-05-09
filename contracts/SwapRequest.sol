// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapContract is Initializable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum SwapStatus {
        Pending,
        Approved,
        Rejected,
        Cancelled
    }

    struct SwapRequest {
        uint256 id;
        address sender;
        address receiver;
        address fromToken;
        uint256 fromAmount;
        address destToken;
        uint256 destAmount;
        SwapStatus status;
    }

    address public treasury;
    uint8 public taxFee;
    uint private requestCount;
    mapping(uint256 => SwapRequest) public swapRequests;

    event SwapRequestCreated(
        uint256 indexed requestId,
        address fromToken,
        address destToken,
        uint256 fromAmount,
        uint256 destAmount
    );

    event SwapRequestApproved(
        uint256 indexed requestId,
        address fromToken,
        address destToken,
        uint256 fromAmount,
        uint256 destAmount,
        SwapStatus status
    );

    event SwapRequestStatusChanged(
        uint256 indexed requestId,
        SwapStatus status
    );
    event TreasuryUpdated(address indexed newTreasury);
    event TransactionFeeUpdated(uint256 newFee);

    constructor(address _treasury) Ownable(msg.sender) {
        treasury = _treasury;
        _disableInitializers();
    }

    function initialize(address _treasury) external initializer onlyOwner {
        treasury = _treasury;
        taxFee = 5;
    }

    function createRequestSwap(
        address _receiver,
        address _fromToken,
        uint256 _fromAmount,
        address _destToken,
        uint256 _destAmount
    ) external nonReentrant {
        require(_receiver != address(0), "Invalid receiver address");
        require(_fromToken != address(0), "Invalid fromToken address");
        require(_destToken != address(0), "Invalid destToken address");

        address sender = msg.sender;
        IERC20 fromToken = IERC20(_fromToken);

        fromToken.safeTransferFrom(sender, address(this), _fromAmount);

        SwapRequest memory request = SwapRequest({
            id: ++requestCount,
            sender: sender,
            receiver: _receiver,
            fromToken: _fromToken,
            destToken: _destToken,
            fromAmount: _fromAmount,
            destAmount: _destAmount,
            status: SwapStatus.Pending
        });
        swapRequests[requestCount] = request;

        emit SwapRequestCreated(
            request.id,
            request.fromToken,
            request.destToken,
            request.fromAmount,
            request.destAmount
        );
    }

    function approveRequestSwap(
        uint256 _requestId_
    ) external nonReentrant verifyRequest(_requestId_) {
        SwapRequest memory request = swapRequests[_requestId_];

        require(msg.sender == request.receiver, "Must be receiver");

        IERC20 fromToken = IERC20(request.fromToken);
        IERC20 destToken = IERC20(request.destToken);

        uint256 tokenAmountSenderWillReceive = ((100 - taxFee) *
            request.destAmount) / 100;
        uint256 tokenAmountReceiverWillReceive = ((100 - taxFee) *
            request.fromAmount) / 100;

        destToken.safeTransferFrom(
            msg.sender,
            address(this),
            request.destAmount
        );
        destToken.transfer(request.sender, tokenAmountSenderWillReceive);
        fromToken.transfer(msg.sender, tokenAmountReceiverWillReceive);

        fromToken.transfer(treasury, (taxFee * request.fromAmount) / 100);
        destToken.transfer(treasury, (taxFee * request.destAmount) / 100);

        swapRequests[_requestId_].status = SwapStatus.Approved;

        emit SwapRequestApproved(
            request.id,
            request.fromToken,
            request.destToken,
            request.fromAmount,
            request.destAmount,
            SwapStatus.Approved
        );
    }

    function rejectRequestSwap(
        uint256 _requestId_
    ) external nonReentrant verifyRequest(_requestId_) {
        SwapRequest memory request = swapRequests[_requestId_];

        require(msg.sender == request.receiver, "Must be receiver");
        IERC20(request.fromToken).transfer(request.sender, request.fromAmount);

        swapRequests[_requestId_].status = SwapStatus.Rejected;
        emit SwapRequestStatusChanged(_requestId_, SwapStatus.Rejected);
    }

    function cancelRequestSwap(
        uint256 _requestId_
    ) external nonReentrant verifyRequest(_requestId_) {
        SwapRequest memory request = swapRequests[_requestId_];

        require(msg.sender == request.sender, "Must be sender");
        IERC20(request.fromToken).transfer(msg.sender, request.fromAmount);

        swapRequests[_requestId_].status = SwapStatus.Cancelled;
        emit SwapRequestStatusChanged(_requestId_, SwapStatus.Cancelled);
    }

    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Treasury address cannot be zero");
        treasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

    function updateTransactionFee(uint8 _newFee) external onlyOwner {
        taxFee = _newFee;
        emit TransactionFeeUpdated(_newFee);
    }

    receive() external payable {
        revert("This contract does not accept ETH.");
    }

    fallback() external payable {
        revert("This contract does not accept ETH.");
    }

    modifier verifyRequest(uint256 _requestId) {
        SwapRequest memory request = swapRequests[_requestId];

        require(request.id != 0, "Request not found");
        require(
            request.status == SwapStatus.Pending,
            "Request status not pending"
        );
        _;
    }
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
