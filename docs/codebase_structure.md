# Maybe Codebase Structure

This document outlines the file structure and organization of the Maybe codebase.

## Root Directory Structure

```
maybe/
├── app/                    # Main application code
├── bin/                   # Binary executables
├── config/                # Configuration files
├── db/                    # Database files and migrations
├── docs/                  # Documentation
├── lib/                   # Library modules
├── log/                   # Log files
├── public/                # Public assets
├── storage/               # File storage
├── test/                  # Test files
├── tmp/                   # Temporary files
├── vendor/                # Third-party code
└── .env                   # Environment variables
```

## Application Structure (app/)

```
app/
├── assets/                # Asset pipeline files
│   ├── config/           # Asset configuration
│   ├── images/          # Image files
│   └── stylesheets/     # CSS and SCSS files
│
├── channels/             # Action Cable channels
│
├── controllers/          # Controllers
│   ├── concerns/        # Controller concerns
│   └── api/            # API controllers
│
├── helpers/             # View helpers
│
├── javascript/          # JavaScript files
│   └── controllers/    # Stimulus controllers
│
├── jobs/                # Background jobs
│
├── mailers/            # Email mailers
│
├── models/             # Models
│   ├── account/        # Account-related models
│   │   ├── balance.rb
│   │   ├── entry.rb
│   │   ├── holding.rb
│   │   ├── syncer.rb
│   │   ├── trade.rb
│   │   ├── transaction.rb
│   │   └── valuation.rb
│   │
│   ├── concerns/       # Model concerns
│   │   └── syncable.rb
│   │
│   ├── account.rb      # Base account model
│   ├── credit_card.rb
│   ├── crypto.rb
│   ├── depository.rb
│   ├── exchange_rate.rb
│   ├── family.rb
│   ├── investment.rb
│   ├── loan.rb
│   ├── plaid_account.rb
│   ├── plaid_item.rb
│   ├── property.rb
│   ├── security.rb
│   ├── sync.rb
│   ├── transfer.rb
│   ├── user.rb
│   └── vehicle.rb
│
└── views/              # View templates
    ├── layouts/       # Layout templates
    └── shared/        # Shared partials
```

## Key Model Organization

### Core Financial Models
- `account.rb` - Base account model
- `family.rb` - Family unit model
- `user.rb` - User model

### Account Types
- Asset Accounts:
  - `depository.rb`
  - `investment.rb`
  - `crypto.rb`
  - `property.rb`
  - `vehicle.rb`
  - `other_asset.rb`
- Liability Accounts:
  - `credit_card.rb`
  - `loan.rb`
  - `other_liability.rb`

### Financial Data Models
- `account/balance.rb` - Account balance records
- `account/entry.rb` - Account entries
- `account/holding.rb` - Investment holdings
- `account/trade.rb` - Investment trades
- `account/transaction.rb` - Financial transactions
- `account/valuation.rb` - Account valuations

### Integration Models
- `plaid_item.rb` - Plaid connection
- `plaid_account.rb` - Plaid account data
- `exchange_rate.rb` - Currency exchange rates
- `security.rb` - Investment securities

### Support Models
- `sync.rb` - Synchronization records
- `transfer.rb` - Inter-account transfers
- `category.rb` - Transaction categories
- `tag.rb` - Custom tags
- `budget.rb` - Budget tracking

## Configuration Files (config/)

```
config/
├── application.rb       # Main application configuration
├── database.yml        # Database configuration
├── routes.rb           # Application routes
├── storage.yml        # Storage configuration
└── environments/      # Environment-specific configs
    ├── development.rb
    ├── production.rb
    └── test.rb
```

## Testing Structure (test/)

```
test/
├── controllers/        # Controller tests
├── models/            # Model tests
├── fixtures/          # Test fixtures
├── support/           # Test helpers
└── test_helper.rb     # Test configuration
```

## Development Tools

```
├── .github/           # GitHub configuration
├── .devcontainer/     # Development container config
├── docker-compose.example.yml
├── Dockerfile
└── Procfile.dev      # Development process manager
```

## Notes

1. The application follows standard Rails conventions for file organization
2. Models are primarily organized in the `app/models` directory, following the "fat model, skinny controller" pattern
3. Complex business logic is implemented through concerns rather than service objects
4. The codebase emphasizes server-side processing with minimal JavaScript
5. Testing uses Minitest with fixtures for simplicity and predictability 