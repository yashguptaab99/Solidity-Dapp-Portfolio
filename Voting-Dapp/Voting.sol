// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Voting {
    // State
    // -------------------------------------------------------------------------

    struct Candidate {
        address owner;
        string name;
    }

    struct Election {
        // - metadata
        string title;
        // - start / end times
        uint256 beginRegistrationAt;
        uint256 endRegistrationAt;
        uint256 beginVotingAt;
        uint256 endVotingAt;
    }

    uint256 internal electionIdCounter = 1;

    // ownerAddress => [ electionId => included ]
    mapping(address => mapping(uint256 => bool)) public ownerElectionIds;
    mapping(uint256 => Election) public elections;
    uint256[] public allElections;

    // electionId => [ candidateAddress => included ]
    mapping(uint256 => mapping(address => bool)) public electionCandidates;
    mapping(uint256 => Candidate[]) public electionCandidatesList;
    // candidateAddress => [ electionId => included ]
    mapping(address => mapping(uint256 => bool)) public candidatesElections;

    // electionId => [ voterAddress => bool ]
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    // electionId => [ candidateAddress => voteCount ]
    mapping(uint256 => mapping(address => uint256)) public candidateVotes;

    // Public Functions
    // -------------------------------------------------------------------------

    function createElection(
        string memory _title,
        uint256 _beginRegistrationAt,
        uint256 _endRegistrationAt,
        uint256 _beginVotingAt,
        uint256 _endVotingAt
    ) public returns (uint256) {
        require(bytes(_title).length > 0, "title must be non-empty");
        require(
            _beginRegistrationAt > block.timestamp,
            "registration must begin in the future"
        );
        require(
            _endRegistrationAt > _beginRegistrationAt,
            "registration must end after it begins"
        );
        require(
            _beginVotingAt > _endRegistrationAt,
            "voting must begin after registration ends"
        );
        require(
            _endVotingAt > _beginVotingAt,
            "voting must end after it begins"
        );

        return
            _createElection(
                msg.sender,
                _title,
                _beginRegistrationAt,
                _endRegistrationAt,
                _beginVotingAt,
                _endVotingAt
            );
    }

    function registerAsCandidate(uint256 _electionId, string memory _name)
        public
    {
        require(
            elections[_electionId].beginRegistrationAt != 0,
            "unknown _electionId"
        );
        require(
            block.timestamp > elections[_electionId].beginRegistrationAt,
            "can't register until registration opens"
        );
        require(
            block.timestamp < elections[_electionId].endRegistrationAt,
            "can't register after registration has closed"
        );
        require(
            electionCandidates[_electionId][msg.sender] == false,
            "can't reregister an already-existing candidate"
        );

        _registerAsCandidate(_electionId, _name);
    }

    function vote(uint256 _electionId, address _candidate) public {
        require(
            elections[_electionId].beginRegistrationAt != 0,
            "unknown _electionId"
        );
        require(
            candidatesElections[_candidate][_electionId] == true,
            "_candidate not registered in _electionId"
        );
        require(
            block.timestamp > elections[_electionId].beginVotingAt,
            "can't vote before voting has started"
        );
        require(
            block.timestamp < elections[_electionId].endVotingAt,
            "can't vote after voting has ended"
        );
        require(
            hasVoted[_electionId][msg.sender] != true,
            "can't vote more than once"
        );

        _vote(_electionId, _candidate);
    }

    function getWinner(uint256 _electionId)
        public
        view
        returns (Candidate memory winner, bool tie)
    {
        require(
            elections[_electionId].beginRegistrationAt != 0,
            "unknown _electionId"
        );
        require(
            block.timestamp > elections[_electionId].endVotingAt,
            "can't get winner before voting has closed"
        );

        tie = false;
        winner = electionCandidatesList[_electionId][0];
        uint256 currWinningVotes = 0;
        uint256 currWinningIndex = 0;

        for (
            uint256 index = 0;
            index < electionCandidatesList[_electionId].length;
            index++
        ) {
            Candidate memory candidate = electionCandidatesList[_electionId][
                index
            ];

            if (
                candidateVotes[_electionId][candidate.owner] > currWinningVotes
            ) {
                currWinningIndex = index;
                currWinningVotes = candidateVotes[_electionId][candidate.owner];
                winner = candidate;
            } else if (
                candidateVotes[_electionId][candidate.owner] ==
                currWinningVotes &&
                currWinningIndex != index
            ) {
                tie = true;
            }
        }
    }

    function getAllElectionsLength() public view returns (uint256) {
        return allElections.length;
    }

    // Private Functions
    // -------------------------------------------------------------------------

    function _createElection(
        address _owner,
        string memory _title,
        uint256 _beginRegistrationAt,
        uint256 _endRegistrationAt,
        uint256 _beginVotingAt,
        uint256 _endVotingAt
    ) internal returns (uint256) {
        uint256 _electionId = _nextElectionId();
        ownerElectionIds[_owner][_electionId] = true;
        elections[_electionId] = Election(
            _title,
            _beginRegistrationAt,
            _endRegistrationAt,
            _beginVotingAt,
            _endVotingAt
        );
        allElections.push(_electionId);
        return _electionId;
    }

    function _registerAsCandidate(uint256 _electionId, string memory _name)
        internal
    {
        electionCandidates[_electionId][msg.sender] = true;
        candidatesElections[msg.sender][_electionId] = true;
        electionCandidatesList[_electionId].push(Candidate(msg.sender, _name));
    }

    function _vote(uint256 _electionId, address _candidate) internal {
        hasVoted[_electionId][msg.sender] = true;
        candidateVotes[_electionId][_candidate]++;
    }

    function _nextElectionId() internal returns (uint256) {
        return electionIdCounter++;
    }
}
