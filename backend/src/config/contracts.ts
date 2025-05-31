
export const SEPOLIA_ADDRESSES = {
  DomainRegistration: '0x2544b5d7aAe9A75D37D94aB015998de847386C10' as const,
  NFTMinter: '0x53b02Ee79D1B7a69D25C0DAdC59CBaF5241D2Dd0' as const,
  TokenMinter: '0x2a3D9095ffFCaF9DfA57D1b17D69aEFb449eEd0c' as const,
} as const;

// Domain Registration Contract ABI - Only including the events and functions we need
export const DOMAIN_REGISTRATION_ABI = [
  {
    type: 'event',
    name: 'RegistrationRequested',
    inputs: [
      { name: 'domainName', type: 'string', indexed: false },
      { name: 'requester', type: 'address', indexed: false },
      { name: 'fee', type: 'uint256', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'OwnershipUpdateRequested',
    inputs: [
      { name: 'domainName', type: 'string', indexed: false },
      { name: 'requester', type: 'address', indexed: false },
      { name: 'fee', type: 'uint256', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'RegistrationFeeUpdated',
    inputs: [
      { name: 'newFee', type: 'uint256', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'OwnershipUpdateFeeUpdated',
    inputs: [
      { name: 'newFee', type: 'uint256', indexed: false }
    ]
  }
] as const; 