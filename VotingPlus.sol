// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Import the Ownable contract from OpenZeppelin to manage administrative functions
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable(msg.sender) {

    // Vote
    struct Voter {
        bool isRegistered; //Indique si l'électeur est enregistré
        bool hasVoted;     // Indique si l'électeur a voté
        uint votedProposalId; // ID de la proposition pour laquelle l'électeur a voté
    }

    // Proposition
    struct Proposal {
        string description; //Description de la proposition
        uint voteCount;     // Nombre de votes reçus
    }

    // Etape du processus de vote
    enum WorkflowStatus {
        RegisteringVoters,            // Phase d'enregistrement des électeurs
        ProposalsRegistrationStarted, // Phase de démarrage de l'enregistrement des propositions
        ProposalsRegistrationEnded,   // Phase de fin de l'enregistrement des propositions
        VotingSessionStarted,         // Phase de démarrage de la session de vote
        VotingSessionEnded,           // Phase de fin de la session de vote
        VotesTallied                  // Phase de comptage des votes
    }

    
    WorkflowStatus public workflowStatus; // Status du processus de vote
    Proposal[] public proposals;  // Tableau des propositions
    mapping(address => Voter) public voters; // Mapping des électeurs
    uint public winningProposalId; // ID de la proposition gagnante

    // Events
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event TieDetected(uint[] tiedProposals);


    // Modifier -> Vérifie si le processus de vote est dans une phase donnée
    modifier onlyDuringWorkflow(WorkflowStatus _status) {
        require(workflowStatus == _status, "Action not allowed in the current workflow status");
        _;
    }

    // Fonction pour enregistrer un électeur (Seulement Admin)
    // L'administrateur ne peut pas être enregistré comme électeur
    function registerVoter(address _voter) external onlyOwner onlyDuringWorkflow(WorkflowStatus.RegisteringVoters) {
        require(_voter != owner(), unicode"Vous ne pouvez pas enregistrer l'administrateur comme électeur");
        require(!voters[_voter].isRegistered, "Voter is already registered");

        voters[_voter].isRegistered = true;
        emit VoterRegistered(_voter);
    }

    // Fonction pour démarrer la phase d'enregistrement des propositions (Seulement Admin)
    function startProposalsRegistration() external onlyOwner onlyDuringWorkflow(WorkflowStatus.RegisteringVoters) {
        changeWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted);
    }

    // Fonction pour enregistrer une proposition (Seulement les électeurs enregistrés)
    function registerProposal(string calldata _description) external onlyDuringWorkflow(WorkflowStatus.ProposalsRegistrationStarted) {
        require(voters[msg.sender].isRegistered, "Only registered voters can submit proposals");

        proposals.push(Proposal({
            description: _description,
            voteCount: 0
        }));

        emit ProposalRegistered(proposals.length - 1);
    }

    // Fonction pour terminer la phase d'enregistrement des propositions (Seulement Admin)
    function endProposalsRegistration() external onlyOwner onlyDuringWorkflow(WorkflowStatus.ProposalsRegistrationStarted) {
        changeWorkflowStatus(WorkflowStatus.ProposalsRegistrationEnded);
    }

    // Fonction pour démarrer la session de vote (Seulement Admin)
    function startVotingSession() external onlyOwner onlyDuringWorkflow(WorkflowStatus.ProposalsRegistrationEnded) {
        changeWorkflowStatus(WorkflowStatus.VotingSessionStarted);
    }

    //Fonction pour voir une proposition
    function getProposal(uint _id) external view returns (Proposal memory) {
        require(_id < proposals.length, "Invalid proposal ID");
        return proposals[_id];
    }

    // Fonction pour voter (Seulement les électeurs enregistrés)
    function vote(uint _proposalId) external onlyDuringWorkflow(WorkflowStatus.VotingSessionStarted) {
        require(voters[msg.sender].isRegistered, "Only registered voters can vote");
        require(!voters[msg.sender].hasVoted, "Voter has already voted");
        require(_proposalId < proposals.length, "Invalid proposal ID");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    // Fonction pour terminer la session de vote (Seulement Admin)
    function endVotingSession() external onlyOwner onlyDuringWorkflow(WorkflowStatus.VotingSessionStarted) {
        changeWorkflowStatus(WorkflowStatus.VotingSessionEnded);
    }

    // Fonction pour compter les votes et déterminer la proposition gagnante (Seulement Admin)
    // Gestion des cas d'égalité
    function tallyVotes() external onlyOwner onlyDuringWorkflow(WorkflowStatus.VotingSessionEnded) {
        uint highestVoteCount = 0;
        uint[] memory winningProposals;
        uint winningCount = 0;

        // 
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > highestVoteCount) {
                highestVoteCount = proposals[i].voteCount;
                winningCount = 1;
                winningProposals = new uint[](proposals.length);
                winningProposals[0] = i;
            } else if (proposals[i].voteCount == highestVoteCount) {
                winningProposals[winningCount] = i;
                winningCount++;
            }
        }

        // Cas d'égalité
        if (winningCount > 1) {
            
            uint[] memory tiedProposals = new uint[](winningCount);
            for (uint j = 0; j < winningCount; j++) {
                tiedProposals[j] = winningProposals[j];
            }
            emit TieDetected(tiedProposals);
            
        } else {
            winningProposalId = winningProposals[0];
        }

        changeWorkflowStatus(WorkflowStatus.VotesTallied);
    }

    // Fonction pour obtenir la proposition gagnante
    function getWinner() external view onlyDuringWorkflow(WorkflowStatus.VotesTallied) returns (Proposal memory) {
        return proposals[winningProposalId];
    }

    // Fonction pour changer le status du processus de vote
    function changeWorkflowStatus(WorkflowStatus _newStatus) internal {
        emit WorkflowStatusChange(workflowStatus, _newStatus);
        workflowStatus = _newStatus;
    }
}
