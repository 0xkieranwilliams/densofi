# DensoFi Domain Registration Service

A robust blockchain event listener and domain registration service that monitors Ethereum smart contract events and manages domain registrations with automatic retry and reconnection capabilities.

## Architecture

The service is built with a modular, well-abstracted architecture:

### Core Components

1. **ConnectionManager** - Handles connection management with retry logic and reconnection
2. **DomainService** - Business logic for domain registration and management
3. **MongoService** - MongoDB connection and operations
4. **EventListener** - Blockchain event monitoring
5. **API Server** - REST API for domain data access

### Database Schema

The service uses the following MongoDB collections:

#### Domains Collection
```typescript
{
  Domain_Name: string;           // Unique domain name
  Associated_ERC20_Addr: string; // Associated ERC20 token address
  Verified_Owner_Addr: string;   // Verified owner address
  Chain_Id: bigint;             // Blockchain chain ID
  NFT_Token_Id: bigint;         // Associated NFT token ID
  Expiration_Timestamp: Date;   // Domain expiration date
  createdAt?: Date;             // Creation timestamp
  updatedAt?: Date;             // Last update timestamp
}
```

#### Pending Registrations Collection
```typescript
{
  domainName: string;
  requester: string;
  fee: bigint;
  transactionHash: string;
  blockNumber: bigint;
  timestamp: Date;
  processed: boolean;
}
```

#### Pending Ownership Updates Collection
```typescript
{
  domainName: string;
  requester: string;
  fee: bigint;
  transactionHash: string;
  blockNumber: bigint;
  timestamp: Date;
  processed: boolean;
}
```

## Features

### Robust Connection Management
- **Exponential Backoff Retry Logic**: Automatically retries failed connections with increasing delays
- **Network Error Detection**: Identifies network-related errors and triggers reconnection
- **Graceful Reconnection**: Handles internet connectivity loss and restoration
- **Connection Health Monitoring**: Tracks connection status across all services

### Event Processing
- **Real-time Event Listening**: Monitors blockchain events in real-time
- **Persistent Event Storage**: Stores events in MongoDB for processing
- **Duplicate Prevention**: Prevents duplicate event processing using transaction hashes
- **Batch Processing**: Processes pending events in batches every 30 seconds

### Domain Management
- **Automatic Registration**: Automatically registers domains when events are detected
- **Duplicate Prevention**: Checks if domains are already registered before processing
- **Ownership Updates**: Handles domain ownership transfer events
- **Expiration Management**: Tracks domain expiration dates

## API Endpoints

### Domain Endpoints
- `GET /api/domains` - Get all registered domains
- `GET /api/domains/:name` - Get specific domain by name
- `GET /api/domains/:name/status` - Check if domain is registered

### System Endpoints
- `GET /api/status` - Get service connection status
- `POST /api/process-pending` - Manually trigger pending event processing
- `GET /health` - Health check endpoint

## Environment Variables

```bash
# MongoDB Configuration
MONGO_URL=mongodb://username:password@host:port/database
MONGO_DB=densofi_domains

# Or individual MongoDB components
MONGOHOST=localhost
MONGOPORT=27017
MONGOUSER=username
MONGOPASSWORD=password

# Blockchain Configuration
POLLING_INTERVAL=5000  # Event polling interval in milliseconds

# API Server
PORT=3000
```

## Error Handling

The service implements comprehensive error handling:

### Network Errors
- Detects RPC errors (codes: -32001, -32002, -32003)
- Identifies network-related error messages
- Automatically triggers reconnection for network issues

### Connection Errors
- MongoDB connection failures
- Blockchain RPC connection issues
- Event listener failures

### Processing Errors
- Event processing failures are logged but don't stop the service
- Database operation failures are handled gracefully
- Individual event processing errors don't affect other events

## Retry Configuration

The service uses configurable retry settings:

```typescript
{
  maxRetries: 10,           // Maximum retry attempts
  baseDelay: 1000,          // Base delay in milliseconds
  maxDelay: 60000,          // Maximum delay cap
  backoffMultiplier: 2      // Exponential backoff multiplier
}
```

## Running the Service

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Set environment variables**:
   ```bash
   export MONGO_URL="mongodb://localhost:27017/densofi"
   export MONGO_DB="densofi_domains"
   export POLLING_INTERVAL=5000
   export PORT=3000
   ```

3. **Start the service**:
   ```bash
   npm run start
   ```

The service will:
- Connect to MongoDB with retry logic
- Initialize domain service and create indexes
- Start blockchain event listener
- Start API server
- Begin processing pending events every 30 seconds

## Monitoring

The service provides comprehensive logging:
- Connection status changes
- Event processing
- Error conditions
- Retry attempts
- Processing statistics

Use the `/api/status` endpoint to monitor service health in real-time.

## Graceful Shutdown

The service handles shutdown signals gracefully:
- Stops event listeners
- Closes database connections
- Shuts down API server
- Cleans up resources

## Scalability Considerations

- **Database Indexes**: Optimized indexes for fast queries
- **Event Deduplication**: Prevents duplicate processing
- **Batch Processing**: Processes events in batches for efficiency
- **Connection Pooling**: MongoDB connection pooling for performance
- **Modular Architecture**: Easy to scale individual components

This architecture ensures the service can handle network interruptions gracefully and continue processing events once connectivity is restored. 