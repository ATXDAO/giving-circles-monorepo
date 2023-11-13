// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IGivingCircle.sol";
import "./KYCController.sol";
import "./partialIERC20.sol";
import "./Initialization.sol";
import "./Proposals.sol";

contract GivingCircle is IGivingCircle, AccessControl, Initializable {
    string public name;

    bytes32 public constant LEADER_ROLE = keccak256("LEADER_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant BEAN_PLACEMENT_ADMIN_ROLE =
        keccak256("BEAN_PLACEMENT_ADMIN_ROLE");
    bytes32 public constant FUNDS_MANAGER_ROLE =
        keccak256("FUNDS_MANAGER_ROLE");

    Phase public phase;

    uint256 public beansToDispursePerAttendee;
    uint256 public fundingThreshold;

    uint256 public proposalCount;
    mapping(uint256 => Proposals.Proposal) public proposals;

    uint256 public attendeeCount;
    mapping(uint256 => Attendees.Attendee) public attendees;

    partialIERC20 public erc20Token;
    KYCController public kycController;

    uint public erc20TokenPerBean;

    event ProposalCreated(uint indexed propNumb, address indexed proposer);
    event BeansPlaced(
        uint indexed propNumb,
        uint indexed beansplaced,
        address indexed beanPlacer
    );
    event FundsAllocated();
    event VotingClosed();
    event FundsRedeemed(
        uint indexed fundsWithdrawn,
        address indexed withdrawee
    );

    // constructor(Initialization.GivingCircleInitialization memory init) {
    //     initialize(init);
    // }

    function initialize(
        Initialization.GivingCircleInitialization memory init
    ) public initializer {
        phase = Phase.PROPOSAL_CREATION;

        require(
            init.beansToDispursePerAttendee > 0,
            "You need atleast 1 bean to be dispursed per person!"
        );

        name = init.name;

        beansToDispursePerAttendee = init.beansToDispursePerAttendee;
        fundingThreshold = init.fundingThreshold;
        proposalCount = 0;
        attendeeCount = 0;
        erc20TokenPerBean = 0;

        require(
            init.circleLeaders.length > 0,
            "You need atleast 1 leader for the circle!"
        );

        for (uint256 i = 0; i < init.admins.length; i++) {
            _grantRole(DEFAULT_ADMIN_ROLE, init.admins[i]);
        }

        for (uint256 i = 0; i < init.circleLeaders.length; i++) {
            _grantRole(LEADER_ROLE, init.circleLeaders[i]);
        }

        for (uint256 i = 0; i < init.beanPlacementAdmins.length; i++) {
            _grantRole(BEAN_PLACEMENT_ADMIN_ROLE, init.beanPlacementAdmins[i]);
        }

        for (uint256 i = 0; i < init.fundsManagers.length; i++) {
            _grantRole(FUNDS_MANAGER_ROLE, init.fundsManagers[i]);
        }

        erc20Token = partialIERC20(init.erc20Token);
        kycController = KYCController(init.kycController);
    }

    //Start Phase 1 Core Functions

    // function batchCreateNewProposals(address payable[] memory proposers, string[] memory names, string[] memory contributions) public onlyRole(LEADER_ROLE) {
    //     require(proposers.length > 0, "Please provider one or more proposer!");

    //     for (uint256 i = 0; i < proposers.length; i++) {
    //         createNewProposal(proposers[i], names[i], contributions[i]);
    //     }
    // }

    function batchCreateNewProposals(
        Proposals.Contributor[] memory newContributors
    ) public onlyRole(LEADER_ROLE) {
        require(
            newContributors.length > 0,
            "Please provider one or more proposer!"
        );

        for (uint256 i = 0; i < newContributors.length; i++) {
            createNewProposal(newContributors[i]);
        }
    }

    //add name to proposal.
    //add description to proposal.
    //allow someone to add themself as a proposer, new function createMyNewProposal()?
    //rename createNewProposal to createNewProposalForSomeoneElse()?

    function createNewProposal(
        Proposals.Contributor memory newContributor
    ) public onlyRole(LEADER_ROLE) {
        require(
            phase == Phase.PROPOSAL_CREATION,
            "circle needs to be in proposal creation phase."
        );
        require(
            !hasRole(PROPOSER_ROLE, newContributor.addr),
            "Recipient already present in proposal!"
        );

        uint256 proposalIndex = proposalCount;
        Proposals.Proposal storage newProposal = proposals[proposalIndex];
        newProposal.contributor.addr = newContributor.addr;
        newProposal.contributor.name = newContributor.name;
        newProposal.contributor.contributions = newContributor.contributions;
        newProposal.beansReceived = 0;

        proposalCount++;

        _grantRole(PROPOSER_ROLE, newProposal.contributor.addr);
        emit ProposalCreated(proposalIndex, newProposal.contributor.addr);
    }

    function createNewProposalForMe(
        Proposals.Contributor memory newContributor
    ) public {
        require(
            phase == Phase.PROPOSAL_CREATION,
            "circle needs to be in proposal creation phase."
        );
        require(
            !hasRole(PROPOSER_ROLE, _msgSender()),
            "Recipient already present in proposal!"
        );

        uint256 proposalIndex = proposalCount;
        Proposals.Proposal storage newProposal = proposals[proposalIndex];
        newProposal.contributor.addr = payable(_msgSender());
        newProposal.contributor.name = newContributor.name;
        newProposal.contributor.contributions = newContributor.contributions;
        newProposal.beansReceived = 0;

        proposalCount++;

        _grantRole(PROPOSER_ROLE, newProposal.contributor.addr);
        emit ProposalCreated(proposalIndex, newProposal.contributor.addr);
    }

    // function createNewProposal(address payable proposer, string memory _name, string memory contributions) public onlyRole(LEADER_ROLE) {
    //     require(phase == Phase.PROPOSAL_CREATION, "circle needs to be in proposal creation phase.");
    //     require(!hasRole(PROPOSER_ROLE, proposer), "Recipient already present in proposal!");

    //     _grantRole(PROPOSER_ROLE, proposer);

    //     uint256 proposalIndex = proposalCount;
    //     Proposals.Proposal storage newProposal = proposals[proposalIndex];
    //     newProposal.proposer = proposer;
    //     newProposal.name = _name;
    //     newProposal.contributions = contributions;
    //     newProposal.beansReceived = 0;

    //     proposalCount++;

    //     emit ProposalCreated(proposalIndex, proposer);
    // }

    //In current setup, allows for Megan or circle leader to mass add a list of arrays if they chose to gather them all beforehand
    //or at the event.
    function registerAttendees(
        address[] memory addrs
    ) public onlyRole(LEADER_ROLE) {
        require(addrs.length > 0, "Please provide one or more attendee!");

        for (uint256 i = 0; i < addrs.length; i++) {
            registerAttendee(addrs[i]);
        }
    }

    //In current setup, allows for an iPad to reach a server from a QR code scanned by a wallet. - More offhands approach
    function registerAttendee(address addr) public onlyRole(LEADER_ROLE) {
        require(
            phase == Phase.PROPOSAL_CREATION || phase == Phase.BEAN_PLACEMENT,
            "circle needs to be in the proposal creation or bean placement phases."
        );

        bool isPresent = false;
        for (uint256 i = 0; i < attendeeCount; i++) {
            if (addr == attendees[i].addr) {
                revert(
                    "Supplied address is already present in the number of attendees."
                );
            }
        }

        if (!isPresent) {
            attendees[attendeeCount].addr = addr;
            attendees[attendeeCount]
                .beansAvailable = beansToDispursePerAttendee;
            attendeeCount++;
        }
    }

    function ProgressToBeanPlacementPhase() external onlyRole(LEADER_ROLE) {
        require(
            phase == Phase.PROPOSAL_CREATION,
            "circle needs to be in proposal creation phase."
        );
        require(
            attendeeCount > 0,
            "Need to have at least 1 attendee before progressing further!"
        );
        require(
            proposalCount > 0,
            "Need to have at least 1 proposal before progressing further!"
        );

        phase = Phase.BEAN_PLACEMENT;
    }

    //End Phase 1 Core Functions

    //Start Phase 2 Core Functions

    function placeBeans(
        address attendee,
        uint256 proposalIndex,
        uint256 beanQuantity
    ) internal {
        require(
            phase == Phase.BEAN_PLACEMENT,
            "circle needs to be in bean placement phase."
        );

        require(
            proposalIndex < proposalCount,
            "Please enter a valid proposal index!"
        );
        require(beanQuantity > 0, "Please provide one or more beans to place!");

        bool isPresent = false;
        for (uint256 i = 0; i < attendeeCount; i++) {
            if (attendees[i].addr == attendee) {
                require(
                    attendees[i].beansAvailable >= beanQuantity,
                    "not enough beans held to place bean quantity."
                );

                attendees[i].beansAvailable -= beanQuantity;
                proposals[proposalIndex].beansReceived += beanQuantity;

                isPresent = true;
                emit BeansPlaced(proposalIndex, beanQuantity, attendee);
                break;
            }
        }

        require(isPresent, "attendee not found!");
    }

    function placeBeansMultiple(
        address attendee,
        uint256[] memory indices,
        uint256[] memory beanQuantities
    ) internal {
        for (uint256 i = 0; i < indices.length; i++) {
            placeBeans(attendee, indices[i], beanQuantities[i]);
        }
    }

    function placeMyBeans(
        uint256 proposalIndex,
        uint256 beanQuantity
    ) external {
        placeBeans(msg.sender, proposalIndex, beanQuantity);
    }

    function placeMyBeansMultiple(
        uint256[] memory proposalIndices,
        uint256[] memory beanQuantities
    ) external {
        placeBeansMultiple(msg.sender, proposalIndices, beanQuantities);
    }

    function placeBeansForSomeone(
        address attendee,
        uint256 proposalIndex,
        uint256 beanQuantity
    ) external onlyRole(BEAN_PLACEMENT_ADMIN_ROLE) {
        placeBeans(attendee, proposalIndex, beanQuantity);
    }

    function placeBeansForSomeoneMultiple(
        address attendee,
        uint256[] memory proposalIndices,
        uint256[] memory beanQuantities
    ) external onlyRole(BEAN_PLACEMENT_ADMIN_ROLE) {
        placeBeansMultiple(attendee, proposalIndices, beanQuantities);
    }

    function ProgressToFundsRedemptionPhase() external onlyRole(LEADER_ROLE) {
        require(
            phase == Phase.BEAN_PLACEMENT,
            "circle needs to be in bean placement phase"
        );
        require(
            erc20Token.balanceOf(address(this)) >= fundingThreshold,
            "Circle needs to be funded first!"
        );

        _calcErc20TokenPerBean();
        _allocateFunds();

        phase = Phase.GIFT_REDEEM;
        emit VotingClosed();
    }

    //Start Phase 2 Internal Functions

    function _calcErc20TokenPerBean() internal virtual returns (uint) {
        uint256 availableUSDC = erc20Token.balanceOf(address(this));

        uint256 newerc20TokenPerBean = (availableUSDC) /
            getTotalBeansDispursed();

        erc20TokenPerBean = newerc20TokenPerBean;
        return newerc20TokenPerBean;
    }

    function _allocateFunds() internal {
        uint256 totalAllocated;
        for (uint i = 0; i < proposalCount; i++) {
            uint256 amountToAllocate = proposals[i].beansReceived *
                erc20TokenPerBean;
            proposals[i].contributor.fundsAllocated = amountToAllocate;
            totalAllocated += amountToAllocate;
        }

        emit FundsAllocated();
    }

    //End Phase 2 Internal Functions

    //Start Phase 3 Core Functions
    function redeemFunds(address addr) internal {
        require(
            phase == Phase.GIFT_REDEEM,
            "circle needs to be in gift redeem phase"
        );

        if (address(kycController) != address(0)) {
            require(
                kycController.isUserKyced(addr),
                "You need to be KYCed first!"
            );
        }

        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].contributor.addr == addr) {
                require(
                    !proposals[i].contributor.hasRedeemed,
                    "You already redeemed your gift!"
                );

                erc20Token.approve(
                    address(this),
                    proposals[i].contributor.fundsAllocated
                );
                erc20Token.transferFrom(
                    address(this),
                    proposals[i].contributor.addr,
                    proposals[i].contributor.fundsAllocated
                );
                proposals[i].contributor.hasRedeemed = true;
                emit FundsRedeemed(
                    proposals[i].contributor.fundsAllocated,
                    proposals[i].contributor.addr
                );
                break;
            }
        }
    }

    function redeemFundsForSomeone(
        address addr
    ) external onlyRole(FUNDS_MANAGER_ROLE) {
        redeemFunds(addr);
    }

    function redeemFundsForSomeoneMultiple(
        address[] memory addrs
    ) external onlyRole(FUNDS_MANAGER_ROLE) {
        for (uint256 i = 0; i < addrs.length; i++) {
            redeemFunds(addrs[i]);
        }
    }

    function redeemMyFunds() external onlyRole(PROPOSER_ROLE) {
        redeemFunds(msg.sender);
    }

    function withdrawRemainingFunds(
        address addr
    ) public onlyRole(FUNDS_MANAGER_ROLE) {
        require(
            phase == Phase.GIFT_REDEEM,
            "circle needs to be in gift redeem phase"
        );
        erc20Token.transfer(addr, getLeftoverFunds());
    }

    //End Phase 3 Core Functions

    //Helper Functions
    function getAttendees() public view returns (Attendees.Attendee[] memory) {
        Attendees.Attendee[] memory arr = new Attendees.Attendee[](
            attendeeCount
        );

        for (uint256 i = 0; i < arr.length; i++) {
            arr[i] = attendees[i];
        }

        return arr;
    }

    function getProposals() public view returns (Proposals.Proposal[] memory) {
        Proposals.Proposal[] memory arr = new Proposals.Proposal[](
            proposalCount
        );

        for (uint256 i = 0; i < arr.length; i++) {
            arr[i] = proposals[i];
        }

        return arr;
    }

    function getAvailableBeans(address addr) external view returns (uint256) {
        for (uint256 i = 0; i < attendeeCount; i++) {
            if (attendees[i].addr == addr) {
                return attendees[i].beansAvailable;
            }
        }

        return 0;
    }

    function getTotalBeansDispursed() public view returns (uint256) {
        return attendeeCount * beansToDispursePerAttendee;
    }

    function getLeftoverFunds() public view returns (uint256) {
        uint256 currentBalance = erc20Token.balanceOf(address(this));
        uint256 currentRedeemedAmount = getTotalUnredeemedFunds();
        return currentBalance - currentRedeemedAmount;
    }

    function getTotalRedeemedFunds() public view returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].contributor.hasRedeemed) {
                total += proposals[i].contributor.fundsAllocated;
            }
        }

        return total;
    }

    function getTotalUnredeemedFunds() public view returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < proposalCount; i++) {
            if (!proposals[i].contributor.hasRedeemed) {
                total += proposals[i].contributor.fundsAllocated;
            }
        }

        return total;
    }

    function getTotalAllocatedFunds() public view returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < proposalCount; i++) {
            total += proposals[i].contributor.fundsAllocated;
        }

        return total;
    }
}
