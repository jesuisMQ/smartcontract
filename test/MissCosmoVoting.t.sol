// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/MissCosmoVoting.sol";

contract MockV3Aggregator {
    int256 private price;

    constructor(int256 _price) {
        price = _price;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, price, 0, 0, 0);
    }
}

contract MissCosmoVotingTest is Test {
    MissCosmoVoting voting;

    address owner = address(1);
    address user = address(2);

    MockV3Aggregator mockFeed;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CandidateCreated(
        uint8 indexed candidateId,
        address indexed owner,
        string metadataCID
    );

    event VotePurchased(
        address indexed voter,
        uint8 indexed candidateId,
        uint8 indexed packageId,
        uint256 votes,
        uint256 ethPaid
    );

    event Withdraw(address indexed owner, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.startPrank(owner);

        mockFeed = new MockV3Aggregator(3000 * 1e8);

        voting = new MissCosmoVoting(address(mockFeed));

        string[] memory cids = new string[](2);
        cids[0] = "cid-1";
        cids[1] = "cid-2";

        voting.addCandidates(cids);

        vm.stopPrank();

        vm.deal(user, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _openVoting() internal {
        vm.prank(owner);
        voting.setEndTime(block.timestamp + 1 days);
    }

    /*//////////////////////////////////////////////////////////////
                            BASIC CHECKS
    //////////////////////////////////////////////////////////////*/

    function testOwnerSetCorrectly() public view {
        assertEq(voting.owner(), owner);
    }

    function testCandidateCount() public view {
        assertEq(voting.candidateCount(), 2);
    }

    function testGetCandidate() public view {
        MissCosmoVoting.Candidate memory c = voting.getCandidate(0);

        assertEq(c.id, 0);
        assertEq(c.owner, owner);
        assertEq(c.metadataCID, "cid-1");
        assertEq(c.totalVotes, 0);
    }

    /*//////////////////////////////////////////////////////////////
                               VOTING
    //////////////////////////////////////////////////////////////*/

    function testVote() public {
        _openVoting();

        uint256 requiredEth = voting.getRequiredEth(1e18);

        vm.prank(user);
        voting.vote{value: requiredEth}(0, 0);

        MissCosmoVoting.Candidate memory c = voting.getCandidate(0);

        assertEq(c.totalVotes, 5);
        assertEq(voting.candidateVotes(0), 5);
    }

    function testRevertInvalidPackage() public {
        _openVoting();

        vm.prank(user);

        vm.expectRevert(MissCosmoVoting.InvalidPackage.selector);
        voting.vote(0, 99);
    }

    function testRevertInsufficientETH() public {
        _openVoting();

        vm.prank(user);

        vm.expectRevert(MissCosmoVoting.InsufficientETH.selector);
        voting.vote{value: 1 wei}(0, 0);
    }

    function testRevertVotingClosed() public {
        vm.prank(owner);
        voting.setEndTime(block.timestamp + 1 days);

        vm.warp(block.timestamp + 2 days);

        vm.prank(user);

        vm.expectRevert(MissCosmoVoting.VotingClosed.selector);
        voting.vote{value: 1 ether}(0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                               WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testWithdraw() public {
        _openVoting();

        uint256 requiredEth = voting.getRequiredEth(1e18);

        vm.prank(user);
        voting.vote{value: requiredEth}(0, 0);

        uint256 beforeBalance = owner.balance;

        vm.prank(owner);
        voting.withdraw();

        uint256 afterBalance = owner.balance;

        assertGt(afterBalance, beforeBalance);
    }

    function testRevertWithdrawNotOwner() public {
        vm.prank(user);

        vm.expectRevert(MissCosmoVoting.NotOwner.selector);
        voting.withdraw();
    }

    function testEmitWithdraw() public {
        _openVoting();

        uint256 requiredEth = voting.getRequiredEth(1e18);

        vm.prank(user);
        voting.vote{value: requiredEth}(0, 0);

        uint256 balance = address(voting).balance;

        vm.expectEmit(true, false, false, true);
        emit Withdraw(owner, balance);

        vm.prank(owner);
        voting.withdraw();
    }

    /*//////////////////////////////////////////////////////////////
                               ORACLE
    //////////////////////////////////////////////////////////////*/

    function testGetEthPrice() public view {
        uint256 price = voting.getEthPrice();
        assertEq(price, 3000 * 1e18);
    }

    function testGetRequiredEth() public view {
        uint256 eth = voting.getRequiredEth(1e18);
        assertApproxEqAbs(eth, 333333333333333, 1e12);
    }

    function testRevertInvalidOracle() public {
        MockV3Aggregator bad = new MockV3Aggregator(0);
        MissCosmoVoting v = new MissCosmoVoting(address(bad));

        vm.expectRevert("Invalid oracle");
        v.getEthPrice();
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    function testEmitCandidateCreated() public {
        vm.startPrank(owner);

        string[] memory cids = new string[](1);
        cids[0] = "ipfs://newCandidate";

        vm.expectEmit(true, true, false, true);
        emit CandidateCreated(2, owner, "ipfs://newCandidate");

        voting.addCandidates(cids);

        vm.stopPrank();
    }

    function testEmitVotePurchased() public {
        _openVoting();

        uint256 requiredEth = voting.getRequiredEth(1e18);

        vm.expectEmit(true, true, true, true);
        emit VotePurchased(user, 0, 0, 5, requiredEth);

        vm.prank(user);
        voting.vote{value: requiredEth}(0, 0);
    }
}