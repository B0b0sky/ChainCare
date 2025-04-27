# ChainCare

ChainCare is a decentralized healthcare records management system built on Clarity smart contracts where patients control access to their medical data and can monetize anonymous health statistics for research.

## Overview

This smart contract enables a secure and patient-controlled healthcare data management system with the following features:

- **Patient Control**: Patients own their medical records and explicitly authorize healthcare providers to access them
- **Provider Access**: Medical providers can request and receive access to patient records
- **Research Contributions**: Patients can opt-in to share anonymous health data for research
- **Monetization**: Patients receive rewards for contributing their anonymous data to research projects

## Contract Functions

### Patient Functions
- `register-patient`: Register as a new patient in the system
- `update-medical-record`: Update your medical record data hash
- `authorize-provider`: Grant a provider access to your medical records
- `revoke-provider-access`: Revoke a provider's access to your records
- `toggle-anonymous-sharing`: Enable/disable sharing of anonymous data for research

### Provider Functions
- `register-provider`: Register as a healthcare provider
- `access-patient-record`: Access a patient's record (if authorized)

### Research Functions
- `create-research-project`: Create a new research project with rewards
- `contribute-to-research`: Contribute anonymous data to a research project
- `claim-research-reward`: Claim rewards for research contributions

### Read-Only Functions
- `get-patient-info`: Get information about a patient
- `check-provider-access`: Check if a provider has access to a patient's records
- `get-provider-info`: Get information about a provider
- `get-research-project`: Get details about a research project
- `get-contribution-info`: Get information about a patient's research contribution

## Development

This contract is designed to be deployed on the Stacks blockchain and can be tested using Clarinet.
