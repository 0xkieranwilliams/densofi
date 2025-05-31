import type { Log } from 'viem';

// Domain Registration Event Types
export interface RegistrationRequestedEvent {
  domainName: string;
  requester: `0x${string}`;
  fee: bigint;
}

export interface OwnershipUpdateRequestedEvent {
  domainName: string;
  requester: `0x${string}`;
  fee: bigint;
}

export interface RegistrationFeeUpdatedEvent {
  newFee: bigint;
}

export interface OwnershipUpdateFeeUpdatedEvent {
  newFee: bigint;
}

// Union type for all domain registration events
export type DomainRegistrationEvent = 
  | RegistrationRequestedEvent 
  | OwnershipUpdateRequestedEvent 
  | RegistrationFeeUpdatedEvent 
  | OwnershipUpdateFeeUpdatedEvent;

// Event log with parsed args
export interface DomainRegistrationEventLog extends Log {
  eventName: string;
  args: DomainRegistrationEvent;
}

// Event handler function type
export type EventHandler<T = DomainRegistrationEvent> = (
  event: T,
  log: Log
) => void | Promise<void>; 