## 0.3.2

- Refactor Response class
- Add jsonWithHeader response
- Add QueryException to model class
- Add Databse helper
- Add Create and InsertMany to the ORM
- Add DB Transaction
- Add Cookies,Integer,asDouble to request class
- Fix request body int fields
- Fix PostgreSQL typo
- Fix drop table issue when table has foreign key

## 0.3.1

- Fix Refresh token bug([#83](https://github.com/vania-dart/framework/issues/83))
- Fix WebSocket connect event

## 0.3.0

- Add Parameter validation conditions for the router([#79](https://github.com/vania-dart/framework/issues/79))
- Add Resource and Any route ([#80](https://github.com/vania-dart/framework/issues/80))
- Refactor Router, Route Handler
- Refactor Controller handler for increasing RPS and decreasing latency
- Refactor Request handler for increase RPS
- Fix Null params ([#81](https://github.com/vania-dart/framework/issues/81))

## 0.2.7

- Optimize PRS
- Refactor Controller handler
- Refactor Request handler
- Refactor Request class
- Add none to response type and await for res close
- Refactor route handler
- Export Database client
- Add URL assets to helper

## 0.2.6

- Refactor Local storage class
- Refactor Cache class
- Refactor Storage class
- Refactor Response class
- Add AWS S3 storage driver
- Add Storage env config

```env
    STORAGE=s3
    STORAGE_S3_BUCKET=''
    STORAGE_S3_SECRET_KEY=''
    STORAGE_S3_ACCESS_KEY=''
    STORAGE_S3_REGION=''
```

## 0.2.5

- Fix Authentication middleware issue
- Fix static file url encoding
- Add Domian to router
- Add JWT env config

```env
    JWT_SECRET_KEY
    JWT_AUDIENCE
    JWT_ID
    JWT_ISSUER
    JWT_SUBJECT
 ```

## 0.2.4

- Fix Route bug
- Add WebSocket middleware
- Refactor Auth middleware

## 0.2.3

- Fix Database connection issue with Isolate

## 0.2.2

- Fix Websocket Join and Left room issue([#63](https://github.com/vania-dart/framework/issues/63))
- Refactor Migration and model
- Add DatabseClient class

## 0.2.1

- Fix Postgresql bug

## 0.2.0

- Add Redis (base code from dedis dart package)
- Add Redis Cache Driver

## 0.1.9

- Fix Isolate bug

## 0.1.8

- Fix public and storage file path
- Refactor Mailable Config to env
- Refactor Migration class, created migration timestamp Add by [S.M. SHAHi](https://github.com/shahi5472)
- Refactor Local cache class name to File cache

## 0.1.7+5

- Add pool and poolsize to DatabaseConfig

## 0.1.7+4

- Fix pgsql bug
- Add alter column to the migration

## 0.1.7+3

- Refactor HttpException to HttpResponseException
- Add abort method to the helper file

## 0.1.7+2

- Fix route group bug

## 0.1.7+1

- Fix env issue

## 0.1.7

- Add deleteTokens and deleteCurrentToken Auth class
- Refactor group routing to use a callback function instead of a list
- Refactor websocket data to payload
- Add Middleware Handler
- Fix Webscoket Route bug
- Update Dependencies
- Add secure bind

## 0.1.6+1

- Fix Storage issues

## 0.1.6

- Fix Websocket bugs
- Refactor Storage Converted Instance Methods to Static Methods
- Refactor Cache Converted Instance Methods to Static Methods

## 0.1.5+1

- Fix env issues

## 0.1.5

- Add Logger
- Add env file

## 0.1.4

- Add Throttle middleware
- Add move for upload file in custom folder
- Add paginate and simplePagination in Eloquent

## 0.1.3

- Add mail

## 0.1.2

- Add multi-isolate server

## 0.1.1+4

- Fix Validation issue on non-required fields

## 0.1.1+3

- Add Singleton base route preFix   to static
- Readme file

## 0.1.1+2

- Fix bug: Cors file and class name

## 0.1.1+1

- Fix bug: http method options and cors error

- ## 0.1.1

- Add Hash class

## 0.1.0

- Initial beta release
- Fix a bug related to WebSocket data events
- Fix authentication check functionality
- Add `isAuthorized` feature
- Add `query_builder` from Eloquent package for enhanced functionality

## 0.0.4

- Fix bug: Authentication refresh token

## 0.0.3+1

- Fix bug: migration columns length
- Add sslmode to the MySqldriver

## 0.0.3

- Fix Bug: Resolved issue with table creation in PostgreSQL

## 0.0.2+1

- Add bigIncrements and  softDeletes columns

## 0.0.2

- Add column index to vania file
- Code formatted

## 0.0.1

- Initial version.
