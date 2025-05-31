import { parseAbiItem, formatEther } from 'viem';
import { publicClient } from './viem-client.js';
import { SEPOLIA_ADDRESSES, DOMAIN_REGISTRATION_ABI } from '../config/contracts.js';
import { ENV } from '../config/env.js';
import { logger } from '../utils/logger.js';
import { DomainService } from './domain-service.js';
import { ConnectionManager } from './connection-manager.js';
import type { 
  RegistrationRequestedEvent, 
  OwnershipUpdateRequestedEvent,
  EventHandler 
} from '../types/events.js';

class DomainEventListener {
  private unwatchRegistration: (() => void) | null = null;
  private unwatchOwnershipUpdate: (() => void) | null = null;
  private isListening: boolean = false;

  // Event handlers
  private onRegistrationRequested: EventHandler<RegistrationRequestedEvent> = async (event, log) => {
    try {
      logger.event('RegistrationRequested', {
        domainName: event.domainName,
        requester: event.requester,
        fee: event.fee.toString(),
        blockNumber: log.blockNumber?.toString() || 'unknown',
        transactionHash: log.transactionHash,
      });

      // Store pending registration in database
      await DomainService.storePendingRegistration({
        domainName: event.domainName,
        requester: event.requester,
        fee: event.fee,
        transactionHash: log.transactionHash || '',
        blockNumber: log.blockNumber || BigInt(0)
      });

    } catch (error) {
      logger.error('Error handling RegistrationRequested event:', error);
      // Don't rethrow to prevent stopping the listener
    }
  };

  private onOwnershipUpdateRequested: EventHandler<OwnershipUpdateRequestedEvent> = async (event, log) => {
    try {
      logger.event('OwnershipUpdateRequested', {
        domainName: event.domainName,
        requester: event.requester,
        fee: event.fee.toString(),
        blockNumber: log.blockNumber?.toString() || 'unknown',
        transactionHash: log.transactionHash,
      });

      // Store pending ownership update in database
      await DomainService.storePendingOwnershipUpdate({
        domainName: event.domainName,
        requester: event.requester,
        fee: event.fee,
        transactionHash: log.transactionHash || '',
        blockNumber: log.blockNumber || BigInt(0)
      });

    } catch (error) {
      logger.error('Error handling OwnershipUpdateRequested event:', error);
      // Don't rethrow to prevent stopping the listener
    }
  };

  /**
   * Start listening for domain registration events
   */
  async startListening(): Promise<void> {
    if (this.isListening) {
      logger.warn('Event listener is already running');
      return;
    }

    try {
      // Watch for RegistrationRequested events
      this.unwatchRegistration = publicClient.watchEvent({
        address: SEPOLIA_ADDRESSES.DomainRegistration,
        event: parseAbiItem('event RegistrationRequested(string domainName, address requester, uint256 fee)'),
        pollingInterval: ENV.POLLING_INTERVAL,
        onLogs: (logs) => {
          logs.forEach(log => {
            if (log.args) {
              this.onRegistrationRequested(log.args as RegistrationRequestedEvent, log);
            }
          });
        },
        onError: async (error) => {
          logger.error('Error watching RegistrationRequested events:', error);
          await ConnectionManager.handleConnectionError(error, 'RegistrationRequested event watcher');
        }
      });

      // Watch for OwnershipUpdateRequested events
      this.unwatchOwnershipUpdate = publicClient.watchEvent({
        address: SEPOLIA_ADDRESSES.DomainRegistration,
        event: parseAbiItem('event OwnershipUpdateRequested(string domainName, address requester, uint256 fee)'),
        pollingInterval: ENV.POLLING_INTERVAL,
        onLogs: (logs) => {
          logs.forEach(log => {
            if (log.args) {
              this.onOwnershipUpdateRequested(log.args as OwnershipUpdateRequestedEvent, log);
            }
          });
        },
        onError: async (error) => {
          logger.error('Error watching OwnershipUpdateRequested events:', error);
          await ConnectionManager.handleConnectionError(error, 'OwnershipUpdateRequested event watcher');
        }
      });

      this.isListening = true;
      logger.info(`🎧 Started listening for domain registration events on contract: ${SEPOLIA_ADDRESSES.DomainRegistration}`);
      logger.info(`📊 Polling interval: ${ENV.POLLING_INTERVAL}ms`);

    } catch (error) {
      logger.error('Failed to start event listener:', error);
      throw error;
    }
  }

  /**
   * Stop listening for events
   */
  stopListening(): void {
    if (!this.isListening) {
      logger.warn('Event listener is not running');
      return;
    }

    try {
      if (this.unwatchRegistration) {
        this.unwatchRegistration();
        this.unwatchRegistration = null;
      }

      if (this.unwatchOwnershipUpdate) {
        this.unwatchOwnershipUpdate();
        this.unwatchOwnershipUpdate = null;
      }

      this.isListening = false;
      logger.info('🔇 Stopped listening for domain registration events');
    } catch (error) {
      logger.error('Error stopping event listener:', error);
    }
  }

  /**
   * Get listening status
   */
  getStatus(): boolean {
    return this.isListening;
  }

  /**
   * Get recent events from the last N blocks and store them
   */
  async getRecentEvents(blockCount: number = 100): Promise<void> {
    try {
      const currentBlock = await publicClient.getBlockNumber();
      const fromBlock = currentBlock - BigInt(blockCount);

      logger.info(`📚 Fetching recent events from block ${fromBlock} to ${currentBlock}`);

      // Get RegistrationRequested events
      const registrationLogs = await publicClient.getLogs({
        address: SEPOLIA_ADDRESSES.DomainRegistration,
        event: parseAbiItem('event RegistrationRequested(string domainName, address requester, uint256 fee)'),
        fromBlock,
        toBlock: currentBlock,
      });

      // Get OwnershipUpdateRequested events
      const ownershipLogs = await publicClient.getLogs({
        address: SEPOLIA_ADDRESSES.DomainRegistration,
        event: parseAbiItem('event OwnershipUpdateRequested(string domainName, address requester, uint256 fee)'),
        fromBlock,
        toBlock: currentBlock,
      });

      logger.info(`Found ${registrationLogs.length} registration events and ${ownershipLogs.length} ownership update events in the last ${blockCount} blocks`);

      // Process recent registration events
      for (const log of registrationLogs) {
        if (log.args) {
          await this.onRegistrationRequested(log.args as RegistrationRequestedEvent, log);
        }
      }

      // Process recent ownership update events
      for (const log of ownershipLogs) {
        if (log.args) {
          await this.onOwnershipUpdateRequested(log.args as OwnershipUpdateRequestedEvent, log);
        }
      }

      // Process the stored events
      await DomainService.processPendingRegistrations();
      await DomainService.processPendingOwnershipUpdates();

    } catch (error) {
      logger.error('Error fetching recent events:', error);
      await ConnectionManager.handleConnectionError(error, 'recent events fetcher');
    }
  }

  /**
   * Restart the event listener (useful for reconnection scenarios)
   */
  async restart(): Promise<void> {
    logger.info('Restarting event listener...');
    this.stopListening();
    
    // Add a small delay to ensure cleanup is complete
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await this.startListening();
  }
}

// Create and export singleton instance
export const domainEventListener = new DomainEventListener();
export default domainEventListener; 