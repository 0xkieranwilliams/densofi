import { logger } from '../utils/logger.js';
import { MongoService } from './mongo-service.js';
import { DomainService } from './domain-service.js';
import { domainEventListener } from './event-listener.js';

export interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  backoffMultiplier: number;
}

export class ConnectionManager {
  private static retryConfig: RetryConfig = {
    maxRetries: 10,
    baseDelay: 1000, // 1 second
    maxDelay: 60000, // 1 minute
    backoffMultiplier: 2
  };

  private static isInitialized = false;
  private static reconnectTimeoutId: NodeJS.Timeout | null = null;

  /**
   * Initialize all services with retry logic
   */
  static async initialize(): Promise<void> {
    if (this.isInitialized) {
      logger.warn('Connection manager already initialized');
      return;
    }

    await this.connectWithRetry();
    // Only set initialized after successful connection
    this.isInitialized = true;
  }

  /**
   * Connect all services with exponential backoff retry logic
   */
  private static async connectWithRetry(retryCount = 0): Promise<void> {
    try {
      logger.info(`Attempting to connect services (attempt ${retryCount + 1}/${this.retryConfig.maxRetries + 1})`);
      
      // Connect to MongoDB
      logger.info('📦 Connecting to MongoDB...');
      await MongoService.connect();
      logger.info('✅ MongoDB connected successfully');
      
      // Initialize domain service
      logger.info('🏗️ Initializing domain service...');
      await DomainService.initialize();
      logger.info('✅ Domain service initialized successfully');
      
      // Start event listener
      logger.info('🎧 Starting event listener...');
      await domainEventListener.startListening();
      logger.info('✅ Event listener started successfully');
      
      // Start processing pending events
      logger.info('⚙️ Starting processing loop...');
      this.startProcessingLoop();
      
      logger.info('🚀 All services connected successfully');
      
      // Clear any existing reconnect timeout
      if (this.reconnectTimeoutId) {
        clearTimeout(this.reconnectTimeoutId);
        this.reconnectTimeoutId = null;
      }
      
    } catch (error) {
      // Properly log the error with all details
      logger.error(`Connection attempt ${retryCount + 1} failed:`, {
        error: error instanceof Error ? {
          name: error.name,
          message: error.message,
          stack: error.stack
        } : error,
        retryCount,
        maxRetries: this.retryConfig.maxRetries
      });
      
      if (retryCount < this.retryConfig.maxRetries) {
        const delay = this.calculateBackoffDelay(retryCount);
        logger.info(`Retrying connection in ${delay}ms...`);
        
        this.reconnectTimeoutId = setTimeout(() => {
          this.connectWithRetry(retryCount + 1);
        }, delay);
      } else {
        logger.error('Max retry attempts reached. Connection failed permanently.');
        throw new Error('Failed to establish connections after maximum retry attempts');
      }
    }
  }

  /**
   * Calculate exponential backoff delay
   */
  private static calculateBackoffDelay(retryCount: number): number {
    const delay = this.retryConfig.baseDelay * Math.pow(this.retryConfig.backoffMultiplier, retryCount);
    return Math.min(delay, this.retryConfig.maxDelay);
  }

  /**
   * Handle connection errors and trigger reconnection
   */
  static async handleConnectionError(error: any, context: string): Promise<void> {
    logger.error(`Connection error in ${context}:`, error);
    
    // Check if it's a network-related error
    if (this.isNetworkError(error)) {
      logger.warn('Network error detected, attempting to reconnect...');
      await this.reconnect();
    }
  }

  /**
   * Check if an error is network-related
   */
  private static isNetworkError(error: any): boolean {
    const networkErrorCodes = [-32001, -32002, -32003]; // Common RPC error codes
    const networkErrorMessages = [
      'resource not found',
      'network error',
      'connection refused',
      'timeout',
      'ECONNREFUSED',
      'ETIMEDOUT',
      'ENOTFOUND'
    ];

    if (error.code && networkErrorCodes.includes(error.code)) {
      return true;
    }

    if (error.message) {
      const errorMessage = error.message.toLowerCase();
      return networkErrorMessages.some(msg => errorMessage.includes(msg));
    }

    return false;
  }

  /**
   * Reconnect all services
   */
  static async reconnect(): Promise<void> {
    logger.info('Initiating reconnection process...');
    
    try {
      // Stop current connections
      await this.disconnect();
      
      // Attempt to reconnect
      await this.connectWithRetry();
      
    } catch (error) {
      logger.error('Reconnection failed:', error);
    }
  }

  /**
   * Disconnect all services
   */
  static async disconnect(): Promise<void> {
    try {
      // Stop event listener
      domainEventListener.stopListening();
      
      // Disconnect from MongoDB
      await MongoService.disconnect();
      
      // Clear any pending reconnect timeout
      if (this.reconnectTimeoutId) {
        clearTimeout(this.reconnectTimeoutId);
        this.reconnectTimeoutId = null;
      }
      
      this.isInitialized = false;
      logger.info('All services disconnected');
    } catch (error) {
      logger.error('Error during disconnect:', error);
    }
  }

  /**
   * Start the processing loop for pending events
   */
  private static startProcessingLoop(): void {
    const processInterval = 30000; // Process every 30 seconds
    
    setInterval(async () => {
      try {
        await DomainService.processPendingRegistrations();
        await DomainService.processPendingOwnershipUpdates();
      } catch (error) {
        logger.error('Error in processing loop:', error);
        // Don't throw here to keep the loop running
      }
    }, processInterval);
    
    logger.info(`Started processing loop with ${processInterval}ms interval`);
  }

  /**
   * Get connection status
   */
  static getStatus(): { initialized: boolean; mongodb: boolean; eventListener: boolean } {
    return {
      initialized: this.isInitialized,
      mongodb: MongoService.getDb() !== null,
      eventListener: domainEventListener.getStatus()
    };
  }

  /**
   * Update retry configuration
   */
  static updateRetryConfig(config: Partial<RetryConfig>): void {
    this.retryConfig = { ...this.retryConfig, ...config };
    logger.info('Retry configuration updated:', this.retryConfig);
  }
} 