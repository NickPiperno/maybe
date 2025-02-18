# Maybe Architecture: Modules and Components

This document provides a comprehensive overview of Maybe's architecture, breaking down its various modules and components.

## 1. Core Financial Modules

### Account Management Module
**Location**: `app/models/account/`
**Components**:
- Account Base System
- Asset Accounts (Depository, Investment, Crypto, Property, Vehicle)
- Liability Accounts (Credit Cards, Loans)
- Balance Tracking
- Holdings Management
- Entry System (Transactions, Trades, Valuations)

### Family & User Module
**Components**:
- Family Management
- User Authentication & Authorization
- Role Management (admin/member)
- Preferences & Settings

### Transfer & Payment Module
**Components**:
- Inter-account Transfers
- Debt Payments
- Auto-matching System
- Currency Exchange

## 2. Integration Modules

### Plaid Integration Module
**Components**:
- Plaid Item Management
- Account Syncing
- Transaction Import
- Data Normalization

### Payment Processing Module
**Components**:
- Stripe Integration
- Subscription Management
- Payment Processing

### Market Data Module
**Components**:
- Synth API Integration
- Market Data Processing
- Security Price Updates

## 3. Synchronization Module
**Components**:
- Account Syncer
- Family Syncer
- Plaid Item Syncer
- Balance Calculator
- Holding Calculator

## 4. Frontend Modules

### UI Components
**Location**: `app/javascript/`
**Components**:
- Stimulus Controllers
- Turbo Frame Handlers
- Custom JavaScript Components

### View Layer
**Location**: `app/views/`
**Components**:
- Layout Templates
- Partial Views
- Component Templates
- TailwindCSS Styling

## 5. Background Processing Module
**Location**: `app/jobs/`
**Components**:
- GoodJob Workers
- Scheduled Tasks
- Data Processing Jobs

## 6. API Module
**Components**:
- API Endpoints
- Data Serialization
- Authentication
- Rate Limiting

## 7. Support Modules

### Configuration Module
**Location**: `config/`
**Components**:
- Environment Settings
- Database Configuration
- Route Definitions
- Initialization

### Testing Module
**Location**: `test/`
**Components**:
- Unit Tests
- Integration Tests
- Fixtures
- Test Helpers

### Development Tools
**Components**:
- Docker Configuration
- Development Environment
- CI/CD Pipeline
- Code Quality Tools

## 8. Security Module
**Components**:
- Authentication System
- Authorization Controls
- API Key Management
- Sensitive Data Handling

## 9. Deployment Module
**Components**:
- Managed Mode Configuration
- Self-hosted Mode Setup
- Docker Deployment
- Environment Management

## 10. Monitoring & Logging Module
**Location**: `log/`
**Components**:
- Application Logging
- Error Tracking
- Performance Monitoring
- Audit Trail

## Architecture Notes

- The application follows Rails MVC architecture
- Emphasizes server-side processing
- Uses "fat model, skinny controller" pattern
- Business logic primarily resides in models and concerns
- Modules are loosely coupled but highly cohesive
- Supports both managed and self-hosted deployments
- Synchronization system ensures data consistency
- Background processing handles time-consuming tasks asynchronously 