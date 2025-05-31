import { Collection } from 'mongodb';
import { MongoService } from './mongo-service.js';
import { logger } from '../utils/logger.js';
import type { 
  Domain, 
  DomainDocument, 
  PendingRegistration, 
  PendingOwnershipUpdate 
} from '../models/domain.js';
import { DnsVerificationService } from './dns-verification-service.js';
import { ENV } from '../config/env.js';

export class DomainService {
  private static domainsCollection: Collection<DomainDocument> | null = null;
  private static pendingRegistrationsCollection: Collection<PendingRegistration> | null = null;
  private static pendingOwnershipUpdatesCollection: Collection<PendingOwnershipUpdate> | null = null;

  /**
   * Initialize the domain service and ensure collections exist
   */
  static async initialize(): Promise<void> {
    try {
      this.domainsCollection = MongoService.getCollection<DomainDocument>('domains');
      this.pendingRegistrationsCollection = MongoService.getCollection<PendingRegistration>('pending_registrations');
      this.pendingOwnershipUpdatesCollection = MongoService.getCollection<PendingOwnershipUpdate>('pending_ownership_updates');

      // Create indexes for better performance
      await this.createIndexes();
      
      logger.info('Domain service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize domain service:', error);
      throw error;
    }
  }

  /**
   * Create database indexes for better performance
   */
  private static async createIndexes(): Promise<void> {
    if (!this.domainsCollection || !this.pendingRegistrationsCollection || !this.pendingOwnershipUpdatesCollection) {
      throw new Error('Collections not initialized');
    }

    try {
      // Create unique index on domain name
      await this.domainsCollection.createIndex({ Domain_Name: 1 }, { unique: true });
      
      // Create indexes for pending collections
      await this.pendingRegistrationsCollection.createIndex({ domainName: 1 });
      await this.pendingRegistrationsCollection.createIndex({ transactionHash: 1 }, { unique: true });
      await this.pendingRegistrationsCollection.createIndex({ processed: 1 });
      
      await this.pendingOwnershipUpdatesCollection.createIndex({ domainName: 1 });
      await this.pendingOwnershipUpdatesCollection.createIndex({ transactionHash: 1 }, { unique: true });
      await this.pendingOwnershipUpdatesCollection.createIndex({ processed: 1 });
      
      logger.info('Database indexes created successfully');
    } catch (error) {
      logger.error('Error creating database indexes:', error);
    }
  }

  /**
   * Check if a domain is already registered
   */
  static async isDomainRegistered(domainName: string): Promise<boolean> {
    if (!this.domainsCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      const domain = await this.domainsCollection.findOne({ Domain_Name: domainName });
      return domain !== null;
    } catch (error) {
      logger.error(`Error checking domain registration for ${domainName}:`, error);
      throw error;
    }
  }

  /**
   * Store a pending registration request
   */
  static async storePendingRegistration(registration: Omit<PendingRegistration, 'timestamp' | 'processed'>): Promise<void> {
    if (!this.pendingRegistrationsCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      const pendingRegistration: PendingRegistration = {
        ...registration,
        timestamp: new Date(),
        processed: false
      };

      await this.pendingRegistrationsCollection.insertOne(pendingRegistration);
      logger.info(`Stored pending registration for domain: ${registration.domainName}`);
    } catch (error: any) {
      if (error.code === 11000) {
        // Duplicate key error - transaction already processed
        logger.warn(`Registration request already exists for transaction: ${registration.transactionHash}`);
        return;
      }
      logger.error(`Error storing pending registration for ${registration.domainName}:`, error);
      throw error;
    }
  }

  /**
   * Store a pending ownership update request
   */
  static async storePendingOwnershipUpdate(update: Omit<PendingOwnershipUpdate, 'timestamp' | 'processed'>): Promise<void> {
    if (!this.pendingOwnershipUpdatesCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      const pendingUpdate: PendingOwnershipUpdate = {
        ...update,
        timestamp: new Date(),
        processed: false
      };

      await this.pendingOwnershipUpdatesCollection.insertOne(pendingUpdate);
      logger.info(`Stored pending ownership update for domain: ${update.domainName}`);
    } catch (error: any) {
      if (error.code === 11000) {
        // Duplicate key error - transaction already processed
        logger.warn(`Ownership update request already exists for transaction: ${update.transactionHash}`);
        return;
      }
      logger.error(`Error storing pending ownership update for ${update.domainName}:`, error);
      throw error;
    }
  }

  /**
   * Process pending registration requests
   */
  static async processPendingRegistrations(): Promise<void> {
    if (!this.pendingRegistrationsCollection || !this.domainsCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      const pendingRegistrations = await this.pendingRegistrationsCollection
        .find({ processed: false })
        .sort({ timestamp: 1 })
        .toArray();

      for (const registration of pendingRegistrations) {
        try {
          // Check if domain is already registered
          const isRegistered = await this.isDomainRegistered(registration.domainName);
          
          if (!isRegistered) {
            // Verify domain ownership
            const isVerified = await this.verifyDomainViaDns(registration.domainName, registration.requester);
            if (!isVerified) {
              logger.warn(`Domain ${registration.domainName} is not verified, skipping`);
              continue;
            }

            // Register the domain
            const domain: DomainDocument = {
              Domain_Name: registration.domainName,
              Associated_ERC20_Addr: '', 
              Verified_Owner_Addr: registration.requester,
              Chain_Id: BigInt(ENV.CHAIN_ID || '11155111'), // Get Chain ID from environment variable, default to Sepolia
              NFT_Token_Id: BigInt(0),
              Expiration_Timestamp: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year from now
              createdAt: new Date(),
              updatedAt: new Date()
            };

            await this.domainsCollection.insertOne(domain);
            logger.info(`Successfully registered domain: ${registration.domainName} for owner: ${registration.requester}`);
          } else {
            logger.warn(`Domain ${registration.domainName} is already registered, skipping`);
          }

          // Mark as processed
          await this.pendingRegistrationsCollection.updateOne(
            { _id: registration._id },
            { $set: { processed: true } }
          );

        } catch (error) {
          logger.error(`Error processing registration for domain ${registration.domainName}:`, error);
          // Continue processing other registrations
        }
      }
    } catch (error) {
      logger.error('Error processing pending registrations:', error);
      throw error;
    }
  }

  /**
   * Process pending ownership update requests
   */
  static async processPendingOwnershipUpdates(): Promise<void> {
    if (!this.pendingOwnershipUpdatesCollection || !this.domainsCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      const pendingUpdates = await this.pendingOwnershipUpdatesCollection
        .find({ processed: false })
        .sort({ timestamp: 1 })
        .toArray();

      for (const update of pendingUpdates) {
        try {
          // Update domain ownership
          const result = await this.domainsCollection.updateOne(
            { Domain_Name: update.domainName },
            { 
              $set: { 
                Verified_Owner_Addr: update.requester,
                updatedAt: new Date()
              } 
            }
          );

          if (result.matchedCount > 0) {
            logger.info(`Successfully updated ownership for domain: ${update.domainName} to: ${update.requester}`);
          } else {
            logger.warn(`Domain ${update.domainName} not found for ownership update`);
          }

          // Mark as processed
          await this.pendingOwnershipUpdatesCollection.updateOne(
            { _id: update._id },
            { $set: { processed: true } }
          );

        } catch (error) {
          logger.error(`Error processing ownership update for domain ${update.domainName}:`, error);
          // Continue processing other updates
        }
      }
    } catch (error) {
      logger.error('Error processing pending ownership updates:', error);
      throw error;
    }
  }

  /**
   * Get all domains
   */
  static async getAllDomains(): Promise<DomainDocument[]> {
    if (!this.domainsCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      return await this.domainsCollection.find({}).toArray();
    } catch (error) {
      logger.error('Error fetching all domains:', error);
      throw error;
    }
  }

  /**
   * Get domain by name
   */
  static async getDomainByName(domainName: string): Promise<DomainDocument | null> {
    if (!this.domainsCollection) {
      throw new Error('Domain service not initialized');
    }

    try {
      return await this.domainsCollection.findOne({ Domain_Name: domainName });
    } catch (error) {
      logger.error(`Error fetching domain ${domainName}:`, error);
      throw error;
    }
  }

  /**
   * Verify domain ownership via DNS TXT record.
   */
  static async verifyDomainViaDns(domainName: string, walletAddress: string): Promise<boolean> {
    logger.info(`Verifying domain ${domainName} for wallet ${walletAddress} via DNS.`);
    try {
      return await DnsVerificationService.verifyDomainOwnership(domainName, walletAddress);
    } catch (error) {
      logger.error(`Error verifying domain ${domainName} via DNS:`, error);
      return false;
    }
  }
} 