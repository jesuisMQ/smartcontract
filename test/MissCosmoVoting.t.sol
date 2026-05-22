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
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (
            0,
            price,
            0,
            0,
            0
        );
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

    event Withdraw(
        address indexed owner,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {

        vm.startPrank(owner);

        mockFeed = new MockV3Aggregator(
            3000 * 1e8
        );

        voting = new MissCosmoVoting(
            address(mockFeed)
        );

        string[] memory cids =
            new string[](2);

        cids[0] = "cid-1";
        cids[1] = "cid-2";

        voting.addCandidates(cids);

        vm.stopPrank();

        vm.deal(user, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testOwnerSetCorrectly ()
        public view
    {
        assertEq(
            voting.owner(),
            owner
        );
    }

    function testPriceFeedSet()
        public view
    {
        assertEq(
            address(voting.priceFeed()),
            address(mockFeed)
        );
    }

    /*//////////////////////////////////////////////////////////////
                           CANDIDATES
    //////////////////////////////////////////////////////////////*/

    function testCandidateCount()
        public view
    {
        assertEq(
            voting.candidateCount(),
            2
        );
    }

    function testGetCandidate()
        public view
    {
        MissCosmoVoting.Candidate memory c =
            voting.getCandidate(0);

        assertEq(c.id, 0);
        assertEq(c.owner, owner);
        assertEq(c.metadataCID, "cid-1");
        assertEq(c.totalVotes, 0);
    }

    function testRevertInvalidCandidate()
        public
    {
        vm.expectRevert(
            MissCosmoVoting.InvalidCandidate.selector
        );

        voting.getCandidate(99);
    }

    /*//////////////////////////////////////////////////////////////
                               VOTING
    //////////////////////////////////////////////////////////////*/

    function testVote()
        public
    {
        uint256 requiredEth =
            voting.getRequiredEth(1e18);

        vm.prank(user);

        voting.vote{
            value: requiredEth
        }(
            0,
            0
        );

        MissCosmoVoting.Candidate memory c =
            voting.getCandidate(0);

        assertEq(c.totalVotes, 5);

        assertEq(
            voting.candidateVotes(0),
            5
        );
    }

    function testRevertInvalidPackage()
        public
    {
        vm.expectRevert(
            MissCosmoVoting.InvalidPackage.selector
        );

        vm.prank(user);

        voting.vote{
            value: 1 ether
        }(
            0,
            99
        );
    }

    function testRevertInsufficientETH()
        public
    {
        vm.expectRevert(
            MissCosmoVoting.InsufficientETH.selector
        );

        vm.prank(user);

        voting.vote{
            value: 1 wei
        }(
            0,
            0
        );
    }

    /*//////////////////////////////////////////////////////////////
                               WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testWithdraw()
        public
    {
        uint256 requiredEth =
            voting.getRequiredEth(1e18);

        vm.prank(user);

        voting.vote{
            value: requiredEth
        }(
            0,
            0
        );

        uint256 beforeBalance =
            owner.balance;

        vm.prank(owner);

        voting.withdraw();

        uint256 afterBalance =
            owner.balance;

        assertGt(
            afterBalance,
            beforeBalance
        );
    }

    function testRevertWithdrawNotOwner()
        public
    {
        vm.expectRevert(
            MissCosmoVoting.NotOwner.selector
        );

        vm.prank(user);

        voting.withdraw();
    }

    /*//////////////////////////////////////////////////////////////
                    UPDATE METADATA
//////////////////////////////////////////////////////////////*/

function testUpdateCandidateMetadata()
    public
{
    vm.prank(owner);

    voting.updateCandidateMetadata(
        0,
        "new-cid"
    );

    MissCosmoVoting.Candidate memory c =
        voting.getCandidate(0);

    assertEq(
        c.metadataCID,
        "new-cid"
    );
}

function testRevertUpdateMetadataNotOwner()
    public
{
    vm.expectRevert(
        MissCosmoVoting.NotOwner.selector
    );

    vm.prank(user);

    voting.updateCandidateMetadata(
        0,
        "hack-cid"
    );
}

function testRevertUpdateInvalidCandidate()
    public
{
    vm.expectRevert(
        MissCosmoVoting.InvalidCandidate.selector
    );

    vm.prank(owner);

    voting.updateCandidateMetadata(
        99,
        "new-cid"
    );
}

    /*//////////////////////////////////////////////////////////////
                               ORACLE
    //////////////////////////////////////////////////////////////*/

    function testGetEthPrice()
        public view
    {
        uint256 price =
            voting.getEthPrice();

        assertEq(
            price,
            3000 * 1e18
        );
    }

    function testGetRequiredEth()
        public view
    {
        uint256 eth =
            voting.getRequiredEth(
                1e18
            );

        assertApproxEqAbs(
            eth,
            333333333333333,
            1e12
        );
    }

    /*//////////////////////////////////////////////////////////////
                           EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testEmitCandidateCreated()
        public
    {
        vm.startPrank(owner);

        string[] memory cids =
            new string[](1);

        cids[0] = "ipfs://newCandidate";

        vm.expectEmit(true, true, false, true);

        emit CandidateCreated(
            2,
            owner,
            "ipfs://newCandidate"
        );

        voting.addCandidates(cids);

        vm.stopPrank();
    }

    function testEmitVotePurchased()
        public
    {
        uint256 requiredEth =
            voting.getRequiredEth(1e18);

        vm.expectEmit(true, true, true, true);

        emit VotePurchased(
            user,
            0,
            0,
            5,
            requiredEth
        );

        vm.prank(user);

        voting.vote{value: requiredEth}(
            0,
            0
        );
    }

    function testEmitWithdraw()
        public
    {
        uint256 requiredEth =
            voting.getRequiredEth(1e18);

        vm.prank(user);

        voting.vote{value: requiredEth}(
            0,
            0
        );

        vm.expectEmit(true, false, false, true);

        emit Withdraw(
            owner,
            requiredEth
        );

        vm.prank(owner);

        voting.withdraw();
    }

    /*//////////////////////////////////////////////////////////////
                           FORK SEPOLIA
    //////////////////////////////////////////////////////////////*/

    function testForkSepoliaPriceFeed()
        public
    {
        string memory RPC =
            vm.envString(
                "SEPOLIA_RPC_URL"
            );

        uint256 forkId =
            vm.createFork(RPC);

        vm.selectFork(forkId);

        address FEED =
            0x694AA1769357215DE4FAC081bf1f309aDC325306;

        AggregatorV3Interface feed =
            AggregatorV3Interface(FEED);

        (
            ,
            int256 price,
            ,
            ,
        ) = feed.latestRoundData();

        console.log(
            "ETH PRICE:",
            uint256(price)
        );

        assertGt(price, 0);
    }

    function testForkSepoliaRealPriceCalc()
        public
    {
        string memory RPC =
            vm.envString(
                "SEPOLIA_RPC_URL"
            );

        uint256 forkId =
            vm.createFork(RPC);

        vm.selectFork(forkId);

        address FEED =
            0x694AA1769357215DE4FAC081bf1f309aDC325306;

        MissCosmoVoting realVoting =
            new MissCosmoVoting(FEED);

        uint256 ethRequired =
            realVoting.getRequiredEth(
                1e18
            );

        console.log(
            "ETH REQUIRED:",
            ethRequired
        );

        assertGt(
            ethRequired,
            0
        );
    }
}