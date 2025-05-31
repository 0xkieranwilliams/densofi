export interface Domain {
  Domain_Name: string;
  Associated_ERC20_Addr: string;
  Verified_Owner_Addr: string;
  Chain_Id: bigint;
  NFT_Token_Id: bigint;
  Expiration_Timestamp: Date;
}

export interface DomainDocument extends Domain {
  _id?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface PendingRegistration {
  domainName: string;
  requester: string;
  fee: bigint;
  transactionHash: string;
  blockNumber: bigint;
  timestamp: Date;
  processed: boolean;
}

export interface PendingOwnershipUpdate {
  domainName: string;
  requester: string;
  fee: bigint;
  transactionHash: string;
  blockNumber: bigint;
  timestamp: Date;
  processed: boolean;
} 