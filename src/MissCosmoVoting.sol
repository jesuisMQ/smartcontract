// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MissCosmoVoting {
    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct VotePackage {
        uint256 usdPrice;
        uint256 votes;
    }

    struct Candidate {
        uint8 id;
        address owner;
        string metadataCID;
        uint256 totalVotes;
    }

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    address public immutable owner;
    AggregatorV3Interface public immutable priceFeed;

    mapping(uint8 => Candidate) public candidates;
    mapping(uint8 => uint256) public candidateVotes;
    mapping(uint8 => VotePackage) public packages;

    uint8 public candidateCount;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CandidateCreated(uint8 indexed candidateId, address indexed owner, string metadataCID);

    event VotePurchased(
        address indexed voter, uint8 indexed candidateId, uint8 indexed packageId, uint256 votes, uint256 ethPaid
    );

    event Withdraw(address indexed owner, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error InvalidCandidate();
    error InvalidPackage();
    error InvalidPriceFeed();
    error InsufficientETH();

    /*//////////////////////////////////////////////////////////////
                              MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _priceFeed) {
        if (_priceFeed == address(0)) revert InvalidPriceFeed();

        owner = msg.sender;
        priceFeed = AggregatorV3Interface(_priceFeed);

        // packages
        packages[0] = VotePackage(1e18, 5);
        packages[1] = VotePackage(5e18, 30);
        packages[2] = VotePackage(10e18, 70);
        packages[3] = VotePackage(25e18, 200);
        packages[4] = VotePackage(50e18, 500);
        packages[5] = VotePackage(100e18, 1200);
    }

    /*//////////////////////////////////////////////////////////////
                           CANDIDATE LOGIC
    //////////////////////////////////////////////////////////////*/

    // 🔥 CHỈ OWNER DEPLOY CONTRACT MỚI ĐƯỢC ADD CANDIDATE
    function addCandidates(string[] memory metadataCIDs) external onlyOwner {
        for (uint256 i = 0; i < metadataCIDs.length; i++) {
            uint8 id = candidateCount++;

            candidates[id] = Candidate({id: id, owner: owner, metadataCID: metadataCIDs[i], totalVotes: 0});

            emit CandidateCreated(id, owner, metadataCIDs[i]);
        }
    }


    function getCandidate(uint8 id) external view returns (Candidate memory) {
        Candidate memory c = candidates[id];
        if (c.owner == address(0)) revert InvalidCandidate();
        return c;
    }

    /*//////////////////////////////////////////////////////////////
                           VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function vote(uint8 candidateId, uint8 packageId) external payable {
        Candidate storage c = candidates[candidateId];

        if (c.owner == address(0)) revert InvalidCandidate();

        VotePackage memory pkg = packages[packageId];

        if (pkg.votes == 0) revert InvalidPackage();

        uint256 requiredEth = getRequiredEth(pkg.usdPrice);

        uint256 minRequired = (requiredEth * 9950) / 10000;

        if (msg.value < minRequired) revert InsufficientETH();

        c.totalVotes += pkg.votes;
        candidateVotes[candidateId] += pkg.votes;

        emit VotePurchased(msg.sender, candidateId, packageId, pkg.votes, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                           OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        (bool success,) = payable(owner).call{value: balance}("");
        require(success, "Withdraw failed");

        emit Withdraw(owner, balance);
    }

    /*//////////////////////////////////////////////////////////////
                            ORACLE
    //////////////////////////////////////////////////////////////*/

    function getEthPrice() public view returns (uint256) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        require(answer > 0, "Invalid oracle");

        return uint256(answer) * 1e10;
    }

    function getRequiredEth(uint256 usdAmount) public view returns (uint256) {
        uint256 ethPrice = getEthPrice();
        return (usdAmount * 1e18) / ethPrice;
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}
    fallback() external payable {}
}
