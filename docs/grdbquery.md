<!--
Downloaded via https://llm.codes by @steipete on September 13, 2025 at 09:46 AM
Source URL: https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery
Total pages processed: 178
URLs filtered: Yes
Content de-duplicated: Yes
Availability strings filtered: Yes
Code blocks only: No
-->

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery

Framework

# GRDBQuery

The SwiftUI companion for GRDB

## Overview

GRDBQuery helps SwiftUI applications access a local SQLite database through GRDB and the SwiftUI environment.

It comes in two flavors:

- The `@Query` property wrapper allows SwiftUI views to directly read and observe the database:

/// Displays an always up-to-date list of database players.
struct PlayerList: View {
@Query(PlayersRequest()) var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

/// Tracks the full list of database players
struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

See Getting Started with @Query.

- The `@EnvironmentStateObject` property wrapper helps building `ObservableObject` models from the SwiftUI environment:

/// Displays an always up-to-date list of database players.
struct PlayerList: View {
@EnvironmentStateObject var model: PlayerListModel = []

init() {
_model = EnvironmentStateObject { env in
PlayerListModel(databaseContext: env.databaseContext)
}
}

var body: some View {
List(model.players) { player in Text(player.name) }
}
}

class PlayerListModel: ObservableObject {
@Published private(set) var players: [Player]
private var cancellable: DatabaseCancellable?

init(databaseContext: DatabaseContext) {
let observation = ValueObservation.tracking { db in
try Player.fetchAll(db)
}
cancellable = observation.start(in: databaseContext.reader, scheduling: .immediate) { error in
// Handle error
} onChange: { players in
self.players = players
}
}
}

See MVVM and Dependency Injection.

Both techniques can be used in a single application, so that developers can run quick experiments, build versatile previews, and also apply strict patterns and conventions. Pick `@Query`, or `@EnvironmentStateObject`, depending on your needs!

## Links

- GitHub repository

- GRDB: the toolkit for SQLite databases, with a focus on application development

- GRDBQuery demo apps

- GRDB demo apps

## Topics

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

### Providing a database context

Custom Database Contexts

Control the database accesses in your application.

`struct DatabaseContext`

A `DatabaseContext` gives access to a GRDB database, and feeds the `@Query` property wrapper via the `databaseContext` SwiftUI environment key.

`enum DatabaseContextError`

An error thrown by `DatabaseContext` when a database access is not available.

Set the database context in the SwiftUI environment of a `Scene`.

`protocol TopLevelDatabaseReader`

A type that provides a read-only database access.

### Controlling observation

`enum QueryObservation`

A `QueryObservation` controls when `@Query` property wrappers are observing their requests.

### The MVVM architecture

MVVM and Dependency Injection

Learn how the `@EnvironmentStateObject` property wrapper helps building MVVM applications.

`struct EnvironmentStateObject`

A property wrapper that instantiates an observable object from the SwiftUI environment.

### Extended Modules

GRDB

SwiftUICore

- GRDBQuery
- Overview
- Links
- Topics

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/gettingstarted

- GRDBQuery
- Getting Started with @Query

Article

# Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

## The SwiftUI Environment

**To use `@Query`, first put a database context in the SwiftUI environment.**

The simplest way to do it is to provide a `DatabaseContext` to a SwiftUI View or Scene:

import GRDBQuery
import SwiftUI

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
}
.databaseContext(.readWrite { /* a GRDB connection */ })
}
}

SwiftUI previews can use specific, in-memory, databases:

#Preview {
MyView()
.databaseContext(.readWrite { /* the database to preview */ })
}

To prevent SwiftUI views from writing in the database, use `readOnly(_:)` instead of `readWrite(_:)`.

Apps that connect to multiple databases need further customization.

See Custom Database Contexts.

## Define a Queryable type

**Next, define a queryable type that publishes database values.**

For example, let’s build `PlayersRequest`, that observes the list of player models, and publishes fresh values whenever the database changes:

import GRDB
import GRDBQuery

/// Tracks the full list of players
struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

Such a “queryable” type conforms to the `Queryable` protocol. It publishes a sequence of values over time, for the `@Query` property wrapper used in SwiftUI views.

There are three extra protocols: `ValueObservationQueryable` (used in the above example), `PresenceObservationQueryable`, and `FetchQueryable`. They are derived from `Queryable`, and provide convenience APIs for observing the database, or performing a single fetch.

Queryable types support customization:

- They can have parameters, so that they can filter or sort a list, fetch a model with a particular identifier, etc. See Adding Parameters to Queryable Types.

- By default, they access the database through a `DatabaseContext`. This can be configured: see Custom Database Contexts.

## Feed a SwiftUI View

**Finally**, define the SwiftUI view that feeds from `PlayersRequest`. It automatically updates its content when the database changes:

struct PlayerList: View {
@Query(PlayersRequest()) var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

Apps that connect to multiple databases, or do not use `DatabaseContext`, need to instruct `@Query` how to access the database. See Custom Database Contexts.

## Handling Errors

**When an error occurs in the queryable type**, the `@Query` value is just not updated. If the database is unavailable when the view appears, `@Query` will just output the default value. To check if an error has occurred, test the `error` property:

var body: some View {
if let error = $players.error {
ContentUnavailableView {
Label("An error occured", systemImage: "xmark.circle")
} description: {
Text(error.localizedDescription)
}
} else {
List(players) { player in Text(player.name) }
}
}
}

## Writing into the database

Apps can, when desired, write in the database with the `SwiftUI/EnvironmentValues/databaseContext` environment key:

import GRDB
import GRDBQuery
import SwiftUI

struct PlayerList: View {
@Environment(\.databaseContext) var databaseContext
@Query(PlayersRequest()) var players: [Player]

var body: some View {
List(players) { player in
List(players) { player in Text(player.name) }
}
.toolbar {
Button("Delete All") {
deletePlayers()
}
}
}

func deletePlayers() {
do {
try databaseContext.writer.write { db in
try Player.deleteAll(db)
}
} catch {
// Handle error
}
}
}

It is possible to prevent SwiftUI views from performing such unrestricted writes. See `readOnly(_:)` and Custom Database Contexts for more information.

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- Getting Started with @Query
- The SwiftUI Environment
- Define a Queryable type
- Feed a SwiftUI View
- Handling Errors
- Writing into the database
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/mvvm

- GRDBQuery
- MVVM and Dependency Injection

Article

# MVVM and Dependency Injection

Learn how the `@EnvironmentStateObject` property wrapper helps building MVVM applications.

## What are we talking about?

Since many programming patterns can be called by the “MVVM” and “Dependency Injection” names, we’ll start by making explicit our usage of those terms in this guide. Hopefully you will feel at home.

### MVVM

_MVVM_ stands for “Model-View-ViewModel”, and it describes an application architecture that distinguishes three types of objects:

- The _View_ is responsible for the UI. In a SwiftUI application, the view is a SwiftUI View.

- The _ViewModel_ implements application logic, feeds a view with on-screen values, and responds to view events. In a SwiftUI application, the type of a view model is often a class that conforms to the `ObservableObject` protocol.

- The _Model_ feeds a view model. The current state of a game, values loaded from the network, values stored in a local database: these are models.

For example, we can have the `Player` model (a regular Swift struct), the `PlayerListViewModel` (an observable object), and the `PlayerListView` (a SwiftUI view). Naming conventions may vary.

An MVVM application is slightly more complex than a naive or “quick and dirty” app, and there exists reasons for that. The wikipedia page describes a few of the MVVM goals. We can add a few technical ones:

- A view model supports many kinds of tests: unit tests, integration tests, end-to-end tests, ui tests, you name it.

- When view models access models through dependency injection, this helps testability. For example, one may want to test a view model in the context of a successful or failing network, or in the context of different database setups (empty database, large database, etc).

- In a SwiftUI application, previews can be seen as quick visual tests. Again, dependency injection makes it possible to run previews in various contexts.

### Dependency Injection

_Dependency Injection_, or DI, is a programming technique that allows separation of concerns. A typical benefit of DI, in an MVVM application, is to make the developer able to instantiate a view model in the desired context.

For example, the application configures a view model with a real network access, while tests and previews use network mocks in order to leverage the desired behaviors.

In the context of databases, the application uses a database persisted on disk, but tests and previews may prefer light and fast in-memory databases configured as desired.

There exist many available DI solutions for Swift, but this guide focuses on the one that is built-in with SwiftUI: **the SwiftUI environment**. Please refer to the SwiftUI documentation to learn more about the environment.

The SwiftUI environment has great developer ergonomics. For example, it is easy to configure previews:

struct MyView_Previews: PreviewProvider {
static var previews: some View {
// Default environment
MyView(...)

// Specific environment
MyView(...).environment(...)
}
}

The SwiftUI environment only applies to view hierarchies, and does not rely on any global or shared DI container. It can’t mess with other parts of the application:

var body: some View {
List {
NavigationLink("Real Stuff") { MyView() }
NavigationLink("Sandbox") { MyView().environment(...) }
}
}

Using the SwiftUI environment as a DI solution does not force your view models to depend on SwiftUI, and it does not mean that the SwiftUI environment is the only way to access dependencies. In the code snippet below, the view model only depends on Combine (for `ObservableObject`), and does not depend on SwiftUI at all:

import Combine // for ObservableObject

class MyViewModel: ObservableObject {
// We don't care if dependencies come from the SwiftUI environment
// or from any other DI solution:
init(database: MyDatabase, network: MyNetwork) { ... }
}

## Lifetimes of a ViewModel

In a MVVM application, a view relies on its view model for grabbing on-screen values, and handling user actions. Keeping the view model alive is important as long as a view is on screen.

SwiftUI ships with a lot of ready-made property wrappers that control the lifetime of view models, and you are probably already using them in your MVVM SwiftUI applications:

- `@Environment` and `@EnvironmentObject` support well view models that outlive the views they feed.

- `@StateObject` support view models that live exactly as long as a SwiftUI view.

- `@ObservedObject` leaves the lifetime control to some other place in the application: it only propagates a view model through a view hierarchy.

We are lacking something, though. Sure, `@StateObject` can define a view model that lives exactly as long as a SwiftUI view. **Unfortunately, `@StateObject` does not support dependency injection via the SwiftUI environment:**

struct MyView: View {
// How to grab dependencies from the SwiftUI environment?
@StateObject var viewModel = MyViewModel(???)
}

If you’ve already scratched your head in front of this puzzle, you’re at the correct place 🙂. And let’s look at the solution below.

## The @EnvironmentStateObject Property Wrapper

`EnvironmentStateObject` is a property wrapper that instantiates an observable object from the SwiftUI environment:

struct MyView: View {
@EnvironmentStateObject var viewModel: MyViewModel

init() {
_viewModel = EnvironmentStateObject { env in
MyViewModel(database: env.database, network: env.network)
}
}
}

In the above sample code, `env.database` and `env.network` are defined with SwiftUI EnvironmentKey. See Getting Started with @Query for some sample code.

`@EnvironmentStateObject` is quite similar to SwiftUI `@StateObject`, and provides the same essential services:

- `@EnvironmentStateObject` instantiates the observable object right before the initial `body` rendering, and deallocates its when the view is no longer rendered.

- When published properties of the observable object change, SwiftUI updates the parts of any view that depend on those properties.

- Get a `Binding` to one of the observable object’s properties using the `$` operator.

#### Previews

`@EnvironmentStateObject` makes it possible to provide specific dependencies in SwiftUI previews:

struct MyView_Previews: PreviewProvider {
static var previews: some View {
// Default database and network
MyView()

// Specific database, default network
MyView().environment(\.database, .empty)

// Specific database and network
MyView()
.environment(\.database, .full)
.environment(\.network, .failingMock)
}
}

#### Extra parameters

You can pass extra parameters:

init(id: String) {
_viewModel = EnvironmentStateObject { env in
MyViewModel(database: env.database, network: env.network, id: id)
}
}
}

#### Stricter MVVM

Some MVVM interpretations do not allow views to instantiate their view models. In this case, adapt the view initializer:

_viewModel = EnvironmentStateObject(makeViewModel)
}
}

Now you can control view model instantiations:

struct RootView: View {
@EnvironmentStateObject var viewModel: RootViewModel

var body: some View {
MyView { _ in viewModel.makeMyViewModel() }
}
}

Yet expressive previews are still available:

struct MyView_Previews: PreviewProvider {
static var previews: some View {
// Default database and network
MyView { env in
MyViewModel(database: env.database, network: env.network)
}

// Specific database, default network
MyView { env in
MyViewModel(database: .empty, network: env.network)
}

// Specific database and network
MyView { _ in
MyViewModel(database: .full, network: .failingMock)
}
}
}

Finally, `@EnvironmentStateObject` handles view model protocols and generic views pretty well:

protocol MyViewModelProtocol: ObservableObject { ... }

@EnvironmentStateObject var viewModel: ViewModel

class MyViewModelA: MyViewModelProtocol { ... }
class MyViewModelB: MyViewModelProtocol { ... }

var body: some View {
HStack {
MyView { _ in viewModel.makeMyViewModelA() }
MyView { _ in viewModel.makeMyViewModelB() }
}
}
}

See the `EnvironmentStateObject` documentation for more information.

## See Also

### The MVVM architecture

`struct EnvironmentStateObject`

A property wrapper that instantiates an observable object from the SwiftUI environment.

- MVVM and Dependency Injection
- What are we talking about?
- MVVM
- Dependency Injection
- Lifetimes of a ViewModel
- The @EnvironmentStateObject Property Wrapper
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/migratingtogrdbquery09

- GRDBQuery
- Migrating To GRDBQuery 0.9

# Migrating To GRDBQuery 0.9

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

## Overview

This release aims at streamlining the application code that feeds the `@Query` property wrapper.

- ✨ You no longer need to write Combine publishers in your queryable types, thanks to new convenience protocols that address the most common use cases.

For example, here is how you can observe the list of players and keep a SwiftUI view in sync:

// NEW in GRDBQuery 0.9
struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

// BEFORE GRDBQuery 0.9
struct PlayersRequest: Queryable {
static var defaultValue: [Player] { [] }

try ValueObservation
.tracking { db in try Player.fetchAll(db) }
.publisher(in: myDatabase.reader, scheduling: .immediate)
.eraseToAnyPublisher()
}
}

- Use `ValueObservationQueryable` for observing a database value and keeping a SwiftUI view in sync.

- Use `PresenceObservationQueryable` for observing whether a database value exists or not.

- Use `FetchQueryable` to perform a single fetch, without database observation.

For your more specific needs, the base `Queryable` protocol still accepts your custom Combine publishers.

- ✨ The new `DatabaseContext` type and the `databaseContext` environment key provides a unified way to read or observe a database from SwiftUI views. This can remove a lot of boilerplate code, such as a custom environment key, or convenience `Query` initializers from this environment key.

See the focused migration guides at the end of this article for more details.

- ✨ The `@Query` property wrapper now exposes its eventual database error. See `error`.

## Breaking changes

All the new features are opt-in, and your GRDBQuery-powered application should continue to work as it is. There are breaking changes that you may have to handle, though:

- The minimum Swift version is now 5.10 (Xcode 15.3+).

- GRDBQuery now depends on GRDB. If you do not want to embed GRDB in your application, _do not upgrade_, and consider vendoring GRDBQuery 0.8.0 in your application.

- The `Queryable` protocol has an associated type that was renamed from `DatabaseContext` to `Context`. Perform a find and replace in your application in order to fix the eventual compiler errors.

- `@Query` is now main-actor isolated. This will automatically isolate views that embed `@Query` to the main actor, and their `async` methods will start running on the main actor as well. This might be undesired, so it is recommended to review the `async` methods of those views.

- If your project uses the `DisableOutwardActorInference` upcoming feature of the Swift compiler, in order to avoid the automatic main actor isolation mentioned above, you will have to annotate some views as `@MainActor`.

Once breaking changes are addressed, keep on reading the focused migration guide that fits your app, below.

## Topics

### Focused Migration Guides

Migrating an application that directly uses a DatabaseQueue or DatabasePool

Migrating an application that uses a database manager

## See Also

### Fundamentals

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- Migrating To GRDBQuery 0.9
- Overview
- Breaking changes
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableparameters

- GRDBQuery
- Adding Parameters to Queryable Types

Article

# Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

## Overview

When a SwiftUI view needs to configure the database values displayed on screen, it will modify the `Queryable` request that feeds the `@Query` property wrapper.

Such configuration can be performed by the view that declares a `@Query` property. It can also be performed by the enclosing view. This article explores all your available options.

## A Configurable Queryable Type

As an example, let’s extend the `PlayersRequest` request type we have seen in Getting Started with @Query. It can now sort players by score, or by name, depending on its `ordering` property.

struct PlayersRequest: ValueObservationQueryable {
enum Ordering {
case byScore
case byName
}

/// How players are sorted.
var ordering: Ordering

static var defaultValue: [Player] { [] }

switch ordering {
case .byScore:
return try Player
.order(Column("score").desc)
.fetchAll(db)
case .byName:
return try Player
.order(Column("name"))
.fetchAll(db)
}
}
}

The `@Query` property wrapper will detect changes in the `ordering` property, and update SwiftUI views accordingly.

## Modifying the Request from the SwiftUI View

SwiftUI views can change the properties of the Queryable request with the SwiftUI bindings provided by the `@Query` property wrapper:

import GRDBQuery
import SwiftUI

struct PlayerList: View {
// Ordering can change through the $players.ordering binding.
@Query(PlayersRequest(ordering: .byScore))
var players: [Player]

var body: some View {
List(players) { player in
HStack {
Text(player.name)
Spacer()
Text("\(player.score) points")
}
}
.toolbar {
ToolbarItem(placement: .navigationBarTrailing) {
ToggleOrderingButton(ordering: $players.ordering)
}
}
}
}

struct ToggleOrderingButton: View {
@Binding var ordering: PlayersRequest.Ordering

var body: some View {
switch ordering {
case .byName:
Button("By Score") { ordering = .byScore }
case .byScore:
Button("By Name") { ordering = .byName }
}
}
}

In the above example, `$players.ordering` is a SwiftUI binding to the `ordering` property of the `PlayersRequest` request.

This binding feeds `ToggleOrderingButton`, which lets the user change the ordering of the request. `@Query` then redraws the view with an updated database content.

When appropriate, you can also use `$players.request`, a SwiftUI binding to the `PlayersRequest` request itself.

## Configuring the Initial Request

The above example has the `PlayerList` view always start with the `.byScore` ordering.

When you want to provide the initial request as a parameter to your view, provide a dedicated initializer:

struct PlayerList: View {
/// No default request

/// Explicit initial request
init(initialRequest: PlayersRequest) {
_players = Query(initialRequest)
}

var body: some View { ... }
}

Defining a default request is still possible:

struct PlayerList: View {
/// Defines the default initial request (ordered by score)
@Query(PlayersRequest(ordering: .byScore))
var players: [Player]

/// Default initial request (by score)
init() { }

## Initializing @Query from a Request Binding

The `@Query` property wrapper can be controlled with a SwiftUI binding, as in the example below:

struct RootView {
@State var request = PlayersRequest(ordering: .byScore)

var body: some View {
PlayerList(request: $request) // Note the `$request` binding here
}
}

struct PlayerList: View {

_players = Query(request)
}

With such a setup, `@Query` updates the database content whenever a change is performed by the `$request` RootView binding, or the `$players` PlayerList bindings.

This is the classic two-way connection enabled by SwiftUI `Binding`.

## Initializing @Query from a Constant Request

Finally, the `init(constant:in:)` initializer allows the enclosing RootView view to control the request without restriction, and without any SwiftUI Binding. However, `$players` binding have no effect:

struct RootView {
var request: PlayersRequest

var body: some View {
PlayerList(constantRequest: request)
}
}

init(constantRequest: PlayersRequest) {
_players = Query(constant: constantRequest)
}

## Summary

**All the `Query` initializers we have seen above can be used in any given SwiftUI view.**

/// Initial request
init(initialRequest: PlayersRequest) {
_players = Query(initialRequest)
}

/// Request binding

/// Constant request
init(constantRequest: PlayersRequest) {
_players = Query(constant: constantRequest)
}

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- Adding Parameters to Queryable Types
- Overview
- A Configurable Queryable Type
- Modifying the Request from the SwiftUI View
- Configuring the Initial Request
- Initializing @Query from a Request Binding
- Initializing @Query from a Constant Request
- Summary
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query

- GRDBQuery
- Query

Structure

# Query

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

@MainActor @propertyWrapper

Query.swift

## Overview

Learn how to use `@Query` in Getting Started with @Query.

## Topics

### Creating a @Query from the ‘databaseContext’ SwiftUI environment.

`init(Request)`

Creates a `Query` that feeds from the `databaseContext` environment key, given an initial `Queryable` request.

Creates a `Query` that feeds from the `databaseContext` environment key, given a SwiftUI binding to its `Queryable` request.

`init(constant: Request)`

Creates a `Query` that feeds from the `databaseContext` environment key, given a `Queryable` request.

### Creating a @Query from other database contexts.

Creates a `Query`, given an initial `Queryable` request, and a key path to a database context in the SwiftUI environment.

Creates a `Query`, given a SwiftUI binding to its `Queryable` request, and a key path to the database in the SwiftUI environment.

Creates a `Query`, given a `Queryable` request, and a key path to the database in the SwiftUI environment.

### Getting the Value

`var wrappedValue: Request.Value`

The last published database value.

A projection of the `Query` that creates bindings to its `Queryable` request.

`struct Wrapper`

A wrapper of the underlying `Query` that creates bindings to its `Queryable` request.

### Debugging Initializers

Those convenience initializers don’t need any key path. They fit `Queryable` types that ignore environment values and use `Void` as their `DatabaseContext`.

Creates a `Query`, given an initial `Queryable` request that uses `Void` as a `Context`.

Creates a `Query`, given a SwiftUI binding to a `Queryable` request that uses `Void` as a `Context`.

Creates a `Query`, given a `Queryable` request that uses `Void` as a `Context`.

## Relationships

### Conforms To

- `Swift.Copyable`
- `Swift.Sendable`
- `SwiftUICore.DynamicProperty`

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- Query
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable

- GRDBQuery
- Queryable

Protocol

# Queryable

A type that feeds the `@Query` property wrapper with a sequence of values over time.

Queryable.swift

## Overview

The role of a `Queryable` type is to build a Combine publisher of database values, with its `publisher(in:)` method. The published values feed SwiftUI views that use the `@Query` property wrapper: each time a new value is published, the view updates accordingly.

A `Queryable` type also provides a `defaultValue`, which is displayed until the publisher publishes its initial value.

The `Queryable` protocol inherits from the standard `Equatable` protocol so that SwiftUI views can configure the database values they display. See Adding Parameters to Queryable Types for more information.

## Example

The sample code below defines `PlayersRequest`, a `Queryable` type that publishes the list of players found in a `DatabaseContext`:

import Combine
import GRDB
import GRDBQuery

/// Tracks the full list of players
struct PlayersRequest: Queryable {
static var defaultValue: [Player] { [] }

try ValueObservation
.tracking { db in try Player.fetchAll(db) }
.publisher(in: context.reader, scheduling: .immediate)
.eraseToAnyPublisher()
}
}

This `PlayersRequest` type will automatically update a SwiftUI view on every database changes, when wrapped by the `@Query` property wrapper:

import GRDBQuery
import SwiftUI

struct PlayerList: View {
@Query(PlayersRequest()) private var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

## Convenience database accesses

The `Queryable` protocol can build arbitrary Combine publishers, from a `DatabaseContext` or from any other data source (see Custom Database Contexts). It is very versatile.

However, many views just want to observe the database, or perform a single database fetch.

That’s why `Queryable` has three derived protocols that address those use cases specifically: `ValueObservationQueryable`, `PresenceObservationQueryable` and `FetchQueryable`.

For example, the `PlayersRequest` defined above can be streamlined as below, for an identical behavior:

struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

## Configurable Queryable Types

A `Queryable` type can have parameters, so that it can filter or sort a list, fetch a model with a particular identifier, etc. See Adding Parameters to Queryable Types.

## Topics

### Associated Types

`associatedtype Context = DatabaseContext`

The type that provides database access.

**Required**

`associatedtype ValuePublisher : Publisher`

The type of the Combine publisher of database values, returned from `publisher(in:)`.

`associatedtype Value`

The type of the published values.

### Database Values

`static var defaultValue: Self.Value`

The default value, used until the Combine publisher publishes its initial value.

**Required** Default implementation provided.

Returns a Combine publisher of database values.

**Required** Default implementations provided.

## Relationships

### Inherits From

- `Swift.Equatable`

### Inherited By

- `FetchQueryable`
- `PresenceObservationQueryable`
- `ValueObservationQueryable`

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- Queryable
- Overview
- Example
- Convenience database accesses
- Configurable Queryable Types
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable

- GRDBQuery
- ValueObservationQueryable

Protocol

# ValueObservationQueryable

A convenience `Queryable` type that observes the database.

ValueObservationQueryable.swift

## Example

The sample code below defines `PlayersRequest`, a queryable type that publishes the list of players found in the database:

import GRDB
import GRDBQuery

struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

This `PlayersRequest` type will automatically update a SwiftUI view on every database changes, when wrapped by the `@Query` property wrapper:

import GRDBQuery
import SwiftUI

struct PlayerList: View {
@Query(PlayersRequest())
private var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

## Runtime Behavior

By default, a `ValueObservationQueryable` type fetches its initial value as soon as a SwiftUI view needs it, from the main thread. This is undesired when the database fetch is slow, because this blocks the user interface. For slow fetches, use the `.async` option, as below. The SwiftUI view will display the default value until the initial fetch is completed.

struct PlayersRequest: ValueObservationQueryable {
// Opt-in for async fetch
static let queryableOptions = QueryableOptions.async

static var defaultValue: [Player] { [] }

The other option is `constantRegion`. When appropriate, it that can enable scheduling optimizations in the most demanding apps. Check the documentation of this option.

## Topics

### Fetching the database value

Returns the observed value.

**Required**

### Controlling the runtime behavior

`static var queryableOptions: QueryableOptions`

Options for the database observation.

**Required** Default implementation provided.

## Relationships

### Inherits From

- `Queryable`
- `Swift.Equatable`
- `Swift.Sendable`

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- ValueObservationQueryable
- Example
- Runtime Behavior
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable

- GRDBQuery
- PresenceObservationQueryable

Protocol

# PresenceObservationQueryable

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

PresenceObservationQueryable.swift

## Example

The sample code below defines `PlayerPresenceRequest`, a queryable type that publishes the presence of a player in the database, given its id:

import GRDB
import GRDBQuery

struct PlayerPresenceRequest: PresenceObservationQueryable {
var playerId: Int64

try Player.fetchOne(db, id: playerId)
}
}

This `PlayerPresenceRequest` type will automatically update a SwiftUI view on every database changes, when wrapped by the `@Query` property wrapper:

import GRDBQuery
import SwiftUI

struct PlayerView: View {

_playerPresence = Query(constant: PlayerPresenceRequest(playerId: playerId))
}

var body: some View {
switch playerPresence {
case .missing:
Text("Player does not exist.")

case .exists(let player):
Text("Player \(player.name) exists.")

case .gone(let player):
Text("Player \(player.name) no longer exists.")
}
}
}

See Adding Parameters to Queryable Types for more explanations about the `PlayerView` initializer.

## Runtime Behavior

By default, a `PresenceObservationQueryable` type fetches its initial value as soon as a SwiftUI view needs it, from the main thread. This is undesired when the database fetch is slow, because this blocks the user interface. For slow fetches, use the `.async` option, as below. The SwiftUI view will display the default value until the initial fetch is completed.

struct PlayersRequest: ValueObservationQueryable {
// Opt-in for async fetch
static let queryableOptions = QueryableOptions.async

static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

The other option is `constantRegion`. When appropriate, it that can enable scheduling optimizations in the most demanding apps. Check the documentation of this option.

## Topics

### Fetching the database value

Returns the observed value, or nil if it does not exist.

**Required**

### Controlling the runtime behavior

`static var queryableOptions: QueryableOptions`

Options for the database observation.

**Required** Default implementation provided.

### Support

`enum Presence`

An enum that with three distinct cases, regarding the presence of a value: `.missing`, `.existing`, or `.gone`. The `.gone` case contains the latest known value.

`func scanPresence<Value>() -> Publishers.Scan<Self, Presence<Value>>`

Transforms the upstream publisher of optional values into a publisher of `Presence` that preserves the last non-nil value.

### Associated Types

`associatedtype WrappedValue : Sendable`

## Relationships

### Inherits From

- `Queryable`
- `Swift.Equatable`
- `Swift.Sendable`

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- PresenceObservationQueryable
- Example
- Runtime Behavior
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable

- GRDBQuery
- FetchQueryable

Protocol

# FetchQueryable

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

FetchQueryable.swift

## Example

The sample code below defines `PlayersRequest`, a queryable type that fetches the list of players found in the database:

import GRDB
import GRDBQuery

struct PlayersRequest: FetchQueryable {
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

This `PlayersRequest` type can feed a SwiftUI view, when wrapped by the `@Query` property wrapper:

import GRDBQuery
import SwiftUI

struct PlayerPicker: View {
@Binding var selection: Player
@Query(PlayersRequest()) private var players: [Player]

var body: some View {
Picker("Select player", selection: $selection) {
ForEach(players) { player in
Text(player.name).tag(player)
}
}
}
}

## Runtime Behavior

By default, a `FetchQueryable` type fetches the value as soon as a SwiftUI view needs it, from the main thread. This is undesired when the database fetch is slow, because this blocks the user interface. For slow fetches, use the `.async` option, as below. The SwiftUI view will display the default value until the fetch is completed.

struct PlayersRequest: FetchQueryable {
// Opt-in for async fetch
static let queryableOptions = QueryableOptions.async

static var defaultValue: [Player] { [] }

## Topics

### Fetching the database value

Returns the fetched value.

**Required**

### Controlling the runtime behavior

`static var queryableOptions: QueryableOptions`

Options for the database fetch.

**Required** Default implementation provided.

## Relationships

### Inherits From

- `Queryable`
- `Swift.Equatable`
- `Swift.Sendable`

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`struct QueryableOptions`

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

- FetchQueryable
- Example
- Runtime Behavior
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions

- GRDBQuery
- QueryableOptions

Structure

# QueryableOptions

Options for `ValueObservationQueryable`, `PresenceObservationQueryable`, and `FetchQueryable`.

struct QueryableOptions

QueryableOptions.swift

## Topics

### Predefined options

`static let async: QueryableOptions`

By default, the initial value is immediately fetched. Use the `async` option when it should be asynchronously fetched.

`static let constantRegion: QueryableOptions`

By default, the tracked database region is not considered constant, and this prevents some scheduling optimizations. Demanding apps may use this `constantRegion` option when appropriate. Check the documentation of `GRDB.ValueObservation.trackingConstantRegion(_:)` before using this option.

`static let assertNoFailure: QueryableOptions`

By default, any error that occurs can be accessed using `error` and is otherwise ignored. With this option, errors that happen while accessing the database terminate the app with a fatal error.

### Initializers

`init(rawValue: Int)`

### Instance Properties

`let rawValue: Int`

### Type Properties

``static let `default`: QueryableOptions``

The default options.

## Relationships

### Conforms To

- `Swift.Equatable`
- `Swift.ExpressibleByArrayLiteral`
- `Swift.OptionSet`
- `Swift.RawRepresentable`
- `Swift.Sendable`
- `Swift.SetAlgebra`

## See Also

### Fundamentals

GRDBQuery 0.9 makes it easier than ever to access the database from SwiftUI views.

Getting Started with @Query

A step-by-step guide for using `@Query` in a SwiftUI application.

Adding Parameters to Queryable Types

Learn how SwiftUI views can configure the database content displayed on screen.

`struct Query`

A property wrapper that subscribes to its `Request` (a `Queryable` type), and invalidates a SwiftUI view whenever the database values change.

`protocol Queryable`

A type that feeds the `@Query` property wrapper with a sequence of values over time.

`protocol ValueObservationQueryable`

A convenience `Queryable` type that observes the database.

`protocol PresenceObservationQueryable`

A convenience `Queryable` type that observes the presence of a value in the database, and remembers its latest state before deletion.

`protocol FetchQueryable`

A convenience `Queryable` type that emits a single value, from a single database fetch. It is suitable for views that must not change once they have appeared on screen.

- QueryableOptions
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/customdatabasecontexts

- GRDBQuery
- Custom Database Contexts

Article

# Custom Database Contexts

Control the database accesses in your application.

## Overview

Applications can perform unrestricted read and write database accesses from their SwiftUI views, for convenience, or rapid prototyping. See Getting Started with @Query for such a setup.

Some apps have other needs, though:

- An app that enforces **database invariants** must disallow unrestricted writes. Database invariants are important for the integrity of application data, as described in the GRDB Concurrency Guide.

- An app that connects to **multiple databases** and has to specify which database a `@Query` property connects to.

We will address those needs below.

## Removing write access from a DatabaseContext

An application controls the `DatabaseContext` that is present in the SwiftUI environment. It is read-only if it is created with the `readOnly(_:)` factory method, even if its underlying database connection can write.

import GRDBQuery
import SwiftUI

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
}
.databaseContext(.readOnly { /* a GRDB connection */ })
}
}

With a read-only context, all attempts to perform writes via the `databaseContext` environment value will fail with `DatabaseContextError.readOnly`.

## Controlling writes with a custom database manager

Now that it is impossible to perform unrestricted writes from the `databaseContext` environment, some applications need views to perform controlled database writes — again, for convenience, or rapid prototyping.

This is case of the GRDBQuery demo app, that uses the techniques described here.

Define a “database manager” type that declares the set of permitted writes. For example:

import GRDB

struct PlayerRepository {
private let writer: GRDB.DatabaseWriter
}

extension PlayerRepository {
/// Inserts a player.
func insert(_ player: Player) {
try writer.write { ... }
}

/// Deletes all players.
func deletePlayers() throws {
try writer.write { ... }
}
}

Then, define a custom SwiftUI environment key for the database manager:

import SwiftUI

private struct PlayerRepositoryKey: EnvironmentKey {
/// The default dbQueue is an empty in-memory database
static var defaultValue: PlayerRepository { /* default PlayerRepository */ }
}

extension EnvironmentValues {
var playerRepository: PlayerRepository {
get { self[PlayerRepositoryKey.self] }
set { self[PlayerRepositoryKey.self] = newValue }
}
}

extension View {
/// Sets the `playerRepository` environment value.

self.environment(\.playerRepository, repository)
}
}

Now, the application can inject a `PlayerRepository` in the environment, and views can use it to write in the database:

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
}
.playerRepository(/* a repository */)
}
}

struct DeletePlayersButton: View {
@Environment(\.playerRepository) var playerRepository

var body: some View {
Button("Delete Players") {
do {
try playerRepository.deletePlayers()
} catch {
// Handle error
}
}
}
}

Finally, let SwiftUI views use the `@Query` property wrapper, as below:

1. Expose a read-only access from the database manager.

2. Update the `View.playerRepository(_:)` method so that it puts a read-only database context in the environment.

extension PlayerRepository {
/// Provides a read-only access to the database.
var reader: GRDB.DatabaseReader { writer }
}

extension View {
/// Sets both the `playerRepository` (for writes) and `databaseContext`
/// (for `@Query`) environment values.

self
.environment(\.playerRepository, repository)
.databaseContext(.readOnly { repository.reader })
}
}

Now everything is working as expected: views can perform controlled writes, and use the `@Query` propoerty wrapper.

## Replacing DatabaseContext with a custom database manager, and connecting to multiple databases

It is also possible to get rid of `DatabaseContext` entirely, and perform all database accesses from a database manager.

This technique can be used to prevent unrestricted reads. It is also useful in applications that connect to multiple databases (just define multiple database managers).

First, stop defining the `databaseContext` environment value, since it is useless.

For `@Query` to be able to feed from a database manager, it is necessary to instruct `Queryable` types to access the database through this database manager, instead of `DatabaseContext`.

- For `Queryable` types, build the publisher from a database manager instead of a database context:

struct MyRequest: Queryable {
// Instead of publisher(in context: DatabaseContext)

...
}
}

- For convenience protocols `ValueObservationQueryable`, `PresenceObservationQueryable` and `FetchQueryable`, have the database manager conform to `TopLevelDatabaseReader`, and explicitly define the context type in queryable types:

extension PlayerRepository: TopLevelDatabaseReader {
/// Provides a read-only access to the database.
var reader: GRDB.DatabaseReader { writer }
}

struct PlayersRequest: ValueObservationQueryable {
typealias Context = PlayerRepository // 👈 Custom context
static var defaultValue: [Player] { [] }

try Player.fetchAll(db)
}
}

Finally, instruct `@Query` to connect to the database manager, with an explicit environment key (see Controlling writes with a custom database manager above):

struct PlayerList: View {
@Query(PlayersRequest(), in: \.playerRepository) // 👈 Custom environment key
var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Providing a database context

`struct DatabaseContext`

A `DatabaseContext` gives access to a GRDB database, and feeds the `@Query` property wrapper via the `databaseContext` SwiftUI environment key.

`enum DatabaseContextError`

An error thrown by `DatabaseContext` when a database access is not available.

Set the database context in the SwiftUI environment of a `Scene`.

`protocol TopLevelDatabaseReader`

A type that provides a read-only database access.

- Custom Database Contexts
- Overview
- Removing write access from a DatabaseContext
- Controlling writes with a custom database manager
- Replacing DatabaseContext with a custom database manager, and connecting to multiple databases
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext

- GRDBQuery
- DatabaseContext

Structure

# DatabaseContext

A `DatabaseContext` gives access to a GRDB database, and feeds the `@Query` property wrapper via the `databaseContext` SwiftUI environment key.

struct DatabaseContext

DatabaseContext.swift

## Overview

`DatabaseContext` provides a read-only access to a database, as well as an optional write access. It can deal with errors that happen during database initialization.

All `Queryable` types, by default, feed from a `DatabaseContext`. This can be configured: see Custom Database Contexts.

To create a `DatabaseContext`, first connect to a database:

let dbQueue = try DatabaseQueue(path: ...)

// Read-write access
let databaseContext = DatabaseContext.readWrite { dbQueue }

// Read-only access
let databaseContext = DatabaseContext.readOnly { dbQueue }

## DatabaseContext and the SwiftUI environment

When put in the SwiftUI environment, a `DatabaseContext` allows SwiftUI views to read, observe, and even write in the database, when desired. For example:

import GRDBQuery
import SwiftUI

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
}
.databaseContext(/* some DatabaseContext on disk */)
}
}

See Getting Started with @Query for more information.

## Creating a DatabaseContext from a database manager

When the application accesses the database through a database manager type, it is still possible to create a `DatabaseContext`, and feed `@Query` property wrappers.

For example, here is how to create a read-only `DatabaseContext` from a `PlayerRepository` database manager:

extension PlayerRepository: TopLevelDatabaseReader {
/// Provides a read-only access to the database, or throws an error if
/// database connection could not be opened.
var reader: GRDB.DatabaseReader {
get throws { /* return a DatabaseReader */ }
}
}

let repository: PlayerRepository = ...
let databaseContext = DatabaseContext.readOnly { try repository.reader }

Learn more about the way to use GRDBQuery with database managers in Custom Database Contexts.

## Topics

### Creating A DatabaseContext

Creates a read-only `DatabaseContext` from an existing database connection.

`static var notConnected: DatabaseContext`

A `DatabaseContext` that throws `DatabaseContextError.notConnected` on every database access.

### Accessing the database

`var reader: any DatabaseReader`

`var writer: any DatabaseWriter`

Returns a database writer.

### Supporting Types

`enum DatabaseContextError`

An error thrown by `DatabaseContext` when a database access is not available.

### Type Methods

Creates a `DatabaseContext` with a read/write access on an existing database connection.

## Relationships

### Conforms To

- `Swift.Copyable`
- `TopLevelDatabaseReader`

## See Also

### Providing a database context

Custom Database Contexts

Control the database accesses in your application.

Set the database context in the SwiftUI environment of a `Scene`.

`protocol TopLevelDatabaseReader`

A type that provides a read-only database access.

- DatabaseContext
- Overview
- DatabaseContext and the SwiftUI environment
- Creating a DatabaseContext from a database manager
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror

- GRDBQuery
- DatabaseContextError

Enumeration

# DatabaseContextError

An error thrown by `DatabaseContext` when a database access is not available.

enum DatabaseContextError

DatabaseContext.swift

## Topics

### Enumeration Cases

`case notConnected`

Database is not connected.

`case readOnly`

Write access is not available.

## Relationships

### Conforms To

- `Swift.Equatable`
- `Swift.Error`
- `Swift.Hashable`
- `Swift.Sendable`

## See Also

### Providing a database context

Custom Database Contexts

Control the database accesses in your application.

`struct DatabaseContext`

A `DatabaseContext` gives access to a GRDB database, and feeds the `@Query` property wrapper via the `databaseContext` SwiftUI environment key.

Set the database context in the SwiftUI environment of a `Scene`.

`protocol TopLevelDatabaseReader`

A type that provides a read-only database access.

- DatabaseContextError
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftui/scene/databasecontext(_:)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/topleveldatabasereader

- GRDBQuery
- TopLevelDatabaseReader

Protocol

# TopLevelDatabaseReader

A type that provides a read-only database access.

protocol TopLevelDatabaseReader

TopLevelDatabaseReader.swift

## Topics

### Instance Properties

`var reader: any DatabaseReader`

Provides a read-only access to the database.

**Required** Default implementation provided.

## Relationships

### Conforming Types

- `AnyDatabaseReader`
- `DatabaseContext`
- `DatabasePool`
- `DatabaseQueue`
- `DatabaseSnapshot`
- `DatabaseSnapshotPool`

## See Also

### Providing a database context

Custom Database Contexts

Control the database accesses in your application.

`struct DatabaseContext`

A `DatabaseContext` gives access to a GRDB database, and feeds the `@Query` property wrapper via the `databaseContext` SwiftUI environment key.

`enum DatabaseContextError`

An error thrown by `DatabaseContext` when a database access is not available.

Set the database context in the SwiftUI environment of a `Scene`.

- TopLevelDatabaseReader
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation

- GRDBQuery
- QueryObservation

Enumeration

# QueryObservation

A `QueryObservation` controls when `@Query` property wrappers are observing their requests.

enum QueryObservation

QueryObservation.swift

## Overview

By default, `@Query` observes its `Queryable` request for the whole duration of the presence of the view in the SwiftUI engine: it subscribes to the request before the first `body` rendering, and cancels the subscription when the view is no longer rendered.

You can spare resources by stopping request observation when views are not on screen, with the `View.queryObservation(_:)` method. It enables request observation in the chosen time intervals, for all `@Query` property wrappers embedded in the view.

Given this general timeline of SwiftUI events:

Initial body rendering
| onAppear onAppear
| | onDisappear | onDisappear
| | | | | End
| | | | | |

- Use `.always` (the default) for subscribing before the first `body` rendering, until the view leaves the SwiftUI engine:

// Initial body rendering End
// | |

MyView().queryObservation(.always)

- Use `.onRender` for subscribing before the first `body` rendering, and then using the `onDisappear` and `onAppear` SwiftUI events for pausing the subscription:

// Initial body rendering
// | onDisappear onAppear onDisappear
// | | | |

MyView().queryObservation(.onRender)

- Use `.onAppear` for letting the `onDisappear` and `onAppear` SwiftUI events control the subscription duration:

// onAppear onDisappear onAppear onDisappear
// | | | |

MyView().queryObservation(.onAppear)

When the built-in strategies do not fit the needs of your application, do not use `View.queryObservation(_:)`. Instead, deal directly with the `\.queryObservationEnabled` environment key:

// Disables observation
MyView().environment(\.queryObservationEnabled, false)

// Enables observation
MyView().environment(\.queryObservationEnabled, true)

## Topics

### Enumeration Cases

`case always`

Requests are always observed.

`case onAppear`

Request observation starts and stops according to the `onAppear` and `onDisappear` View events.

`case onRender`

Request observation starts on the first `body` rendering of the view, and is later stopped and restarted according to the `onAppear` and `onDisappear` View events.

## Relationships

### Conforms To

- `Swift.Equatable`
- `Swift.Hashable`

- QueryObservation
- Overview
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/environmentstateobject



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb

- GRDBQuery
- GRDB

Extended Module

# GRDB

## Topics

### Extended Classes

`extension AnyDatabaseReader`

`extension DatabasePool`

`extension DatabaseQueue`

`extension DatabaseSnapshot`

`extension DatabaseSnapshotPool`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftuicore

- GRDBQuery
- SwiftUICore

Extended Module

# SwiftUICore

## Topics

### Extended Protocols

`extension View`

### Extended Structures

`extension EnvironmentValues`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/gettingstarted).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/mvvm).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/migratingtogrdbquery09)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/gettingstarted)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableparameters)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/customdatabasecontexts)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftui/scene/databasecontext(_:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/topleveldatabasereader)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/mvvm)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/environmentstateobject)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftuicore)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/readonly(_:)

#app-main)

- GRDBQuery
- DatabaseContext
- readOnly(\_:)

Type Method

# readOnly(\_:)

Creates a read-only `DatabaseContext` from an existing database connection.

DatabaseContext.swift

## Discussion

The input closure is evaluated once. If it throws an error, all database reads performed from the resulting context throw that same error.

Attempts to write in the database through the `writer` property throw `DatabaseContextError.readOnly`, even if the input connection can perform writes.

For example:

import GRDBQuery
import SwiftUI

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
}
.databaseContext(.readOnly { /* a GRDB connection */ })
}
}

## See Also

### Creating A DatabaseContext

`static var notConnected: DatabaseContext`

A `DatabaseContext` that throws `DatabaseContextError.notConnected` on every database access.

- readOnly(\_:)
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/readwrite(_:)

#app-main)

- GRDBQuery
- DatabaseContext
- readWrite(\_:)

Type Method

# readWrite(\_:)

Creates a `DatabaseContext` with a read/write access on an existing database connection.

DatabaseContext.swift

## Discussion

The input closure is evaluated once. If it throws an error, all database accesses performed from the resulting context throw that same error.

For example:

import GRDBQuery
import SwiftUI

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
}
.databaseContext(.readWrite { /* a GRDB connection */ })
}
}

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrapper/error

- GRDBQuery
- Query
- Query.Wrapper
- error

Instance Property

# error

Returns the latest request publisher error.

@MainActor
var error: (any Error)? { get }

Query.swift

## Discussion

This error is set whenever an error occurs when accessing a database value.

It is reset to nil when the `Query` is restarted.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/readonly(_:))



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/readwrite(_:)).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/customdatabasecontexts).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableparameters).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrapper/error)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-7u3nj

-7u3nj#app-main)

- GRDBQuery
- Query
- init(\_:)

Initializer

# init(\_:)

Creates a `Query` that feeds from the `databaseContext` environment key, given an initial `Queryable` request.

@MainActor
init(_ request: Request)

Query+DatabaseContext.swift

Available when `Request` conforms to `Queryable` and `Request.Context` is `DatabaseContext`.

## Parameters

`request`

An initial `Queryable` request.

## Discussion

See `init(_:in:)` for more information about the runtime behavior of the returned `Query`.

For example:

struct PlayerList: View {
@Query(PlayersRequest()) private var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Creating a @Query from the ‘databaseContext’ SwiftUI environment.

Creates a `Query` that feeds from the `databaseContext` environment key, given a SwiftUI binding to its `Queryable` request.

`init(constant: Request)`

Creates a `Query` that feeds from the `databaseContext` environment key, given a `Queryable` request.

- init(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-8786d

-8786d#app-main)

- GRDBQuery
- Query
- init(\_:)

Initializer

# init(\_:)

Creates a `Query` that feeds from the `databaseContext` environment key, given a SwiftUI binding to its `Queryable` request.

@MainActor

Query+DatabaseContext.swift

Available when `Request` conforms to `Queryable` and `Request.Context` is `DatabaseContext`.

## Parameters

`request`

A SwiftUI binding to a `Queryable` request.

## Discussion

See `init(_:in:)` for more information about the runtime behavior of the returned `Query`.

For example:

struct RootView {
@State var request: PlayersRequest

var body: some View {
PlayerList($request) // Note the `$request` binding here
}
}

struct PlayerList: View {

_players = Query(request)
}

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Creating a @Query from the ‘databaseContext’ SwiftUI environment.

`init(Request)`

Creates a `Query` that feeds from the `databaseContext` environment key, given an initial `Queryable` request.

`init(constant: Request)`

Creates a `Query` that feeds from the `databaseContext` environment key, given a `Queryable` request.

- init(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(constant:)-20bym

-20bym#app-main)

- GRDBQuery
- Query
- init(constant:)

Initializer

# init(constant:)

Creates a `Query` that feeds from the `databaseContext` environment key, given a `Queryable` request.

@MainActor
init(constant request: Request)

Query+DatabaseContext.swift

Available when `Request` conforms to `Queryable` and `Request.Context` is `DatabaseContext`.

## Parameters

`request`

A `Queryable` request.

## Discussion

See `init(constant:in:)` for more information about the runtime behavior of the returned `Query`.

For example:

struct PlayerList: View {

init(constantRequest request: PlayersRequest) {
_players = Query(constant: request)
}

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Creating a @Query from the ‘databaseContext’ SwiftUI environment.

`init(Request)`

Creates a `Query` that feeds from the `databaseContext` environment key, given an initial `Queryable` request.

Creates a `Query` that feeds from the `databaseContext` environment key, given a SwiftUI binding to its `Queryable` request.

- init(constant:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:in:)-2o5mo

-2o5mo#app-main)

- GRDBQuery
- Query
- init(\_:in:)

Initializer

# init(\_:in:)

Creates a `Query`, given an initial `Queryable` request, and a key path to a database context in the SwiftUI environment.

@MainActor
init(
_ request: Request,

Query.swift

## Parameters

`request`

An initial `Queryable` request.

`keyPath`

A key path to the database in the environment.

## Discussion

The `request` must have a `Context` type identical to the type of `keyPath` in the environment. It can be `DatabaseContext` (the default context of queryable requests), of any other type (see Custom Database Contexts).

For example:

struct PlayerList: View {
@Query(PlayersRequest(), in: \.myDatabase)
private var players: [Player]

var body: some View {
List(players) { player in Text(player.name) }
}
}

The returned `@Query` is akin to the SwiftUI `@State`: it is the single source of truth for the request. In the above example, the request has no parameter, so it does not matter much. But when the request can be modified, it starts to be relevant. In particular, at runtime, after the view has appeared on screen, only the SwiftUI bindings returned by the `projectedValue` wrapper ( `$players`) can update the database content visible on screen by changing the request.

See Adding Parameters to Queryable Types for a longer discussion about `@Query` initializers.

## See Also

### Creating a @Query from other database contexts.

Creates a `Query`, given a SwiftUI binding to its `Queryable` request, and a key path to the database in the SwiftUI environment.

Creates a `Query`, given a `Queryable` request, and a key path to the database in the SwiftUI environment.

- init(\_:in:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:in:)-8jlgq

-8jlgq#app-main)

- GRDBQuery
- Query
- init(\_:in:)

Initializer

# init(\_:in:)

Creates a `Query`, given a SwiftUI binding to its `Queryable` request, and a key path to the database in the SwiftUI environment.

@MainActor
init(

Query.swift

## Parameters

`request`

A SwiftUI binding to a `Queryable` request.

`keyPath`

A key path to the database in the environment.

## Discussion

The `request` must have a `Context` type identical to the type of `keyPath` in the environment. It can be `DatabaseContext` (the default context of queryable requests), of any other type (see Custom Database Contexts).

Both the `request` Binding argument, and the SwiftUI bindings returned by the `projectedValue` wrapper ( `$players`) can update the database content visible on screen by changing the request. See Adding Parameters to Queryable Types for more details.

For example:

struct RootView {
@State private var request: PlayersRequest

var body: some View {
PlayerList($request) // Note the `$request` binding here
}
}

struct PlayerList: View {

_players = Query(request, in: \.myDatabase)
}

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Creating a @Query from other database contexts.

Creates a `Query`, given an initial `Queryable` request, and a key path to a database context in the SwiftUI environment.

Creates a `Query`, given a `Queryable` request, and a key path to the database in the SwiftUI environment.

- init(\_:in:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(constant:in:)

#app-main)

- GRDBQuery
- Query
- init(constant:in:)

Initializer

# init(constant:in:)

Creates a `Query`, given a `Queryable` request, and a key path to the database in the SwiftUI environment.

@MainActor
init(
constant request: Request,

Query.swift

## Parameters

`request`

A `Queryable` request.

`keyPath`

A key path to the database in the environment.

## Discussion

The `request` must have a `Context` type identical to the type of `keyPath` in the environment. It can be `DatabaseContext` (the default context of queryable requests), of any other type (see Custom Database Contexts).

The SwiftUI bindings returned by the `projectedValue` wrapper ( `$players`) can not update the database content: the request is “constant”. See Adding Parameters to Queryable Types for more details.

For example:

struct PlayerList: View {

_players = Query(constant: request, in: \.myDatabase)
}

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Creating a @Query from other database contexts.

Creates a `Query`, given an initial `Queryable` request, and a key path to a database context in the SwiftUI environment.

Creates a `Query`, given a SwiftUI binding to its `Queryable` request, and a key path to the database in the SwiftUI environment.

- init(constant:in:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrappedvalue

- GRDBQuery
- Query
- wrappedValue

Instance Property

# wrappedValue

The last published database value.

@MainActor
var wrappedValue: Request.Value { get }

Query.swift

## See Also

### Getting the Value

A projection of the `Query` that creates bindings to its `Queryable` request.

`struct Wrapper`

A wrapper of the underlying `Query` that creates bindings to its `Queryable` request.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/projectedvalue

- GRDBQuery
- Query
- projectedValue

Instance Property

# projectedValue

A projection of the `Query` that creates bindings to its `Queryable` request.

@MainActor

Query.swift

## Discussion

Learn how to use this projection in the Adding Parameters to Queryable Types guide.

## See Also

### Getting the Value

`var wrappedValue: Request.Value`

The last published database value.

`struct Wrapper`

A wrapper of the underlying `Query` that creates bindings to its `Queryable` request.

- projectedValue
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrapper

- GRDBQuery
- Query
- Query.Wrapper

Structure

# Query.Wrapper

A wrapper of the underlying `Query` that creates bindings to its `Queryable` request.

@dynamicMemberLookup
struct Wrapper

Query.swift

## Topics

### Modifying the Request

Returns a binding to the `Queryable` request itself.

Returns a binding to the property of the `Queryable` request, at a given key path.

### Accessing the latest error

`var error: (any Error)?`

Returns the latest request publisher error.

## See Also

### Getting the Value

`var wrappedValue: Request.Value`

The last published database value.

A projection of the `Query` that creates bindings to its `Queryable` request.

- Query.Wrapper
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-9bg3k



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-81ae1

-81ae1#app-main)

- GRDBQuery
- Query
- init(\_:)

Initializer

# init(\_:)

Creates a `Query`, given a SwiftUI binding to a `Queryable` request that uses `Void` as a `Context`.

@MainActor

Query+VoidContext.swift

Available when `Request` conforms to `Queryable` and `Request.Context` is `()`.

## Parameters

`request`

A SwiftUI binding to a `Queryable` request.

## Discussion

See `init(_:in:)` for more information about the runtime behavior of the returned `Query`.

For example:

struct PlayersRequest: Queryable {
static var defaultValue: [Player] { [] }

// PlayersRequest feeds from nothing (Void)

...
}
}

struct RootView {
@State var request: PlayersRequest

var body: some View {
PlayerList($request) // Note the `$request` binding here
}
}

struct PlayerList: View {

_players = Query(request)
}

var body: some View {
List(players) { player in Text(player.name) }
}
}

## See Also

### Debugging Initializers

`init(Request)`

Creates a `Query`, given an initial `Queryable` request that uses `Void` as a `Context`.

`init(constant: Request)`

Creates a `Query`, given a `Queryable` request that uses `Void` as a `Context`.

- init(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(constant:)-1ko9k



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/dynamicproperty-implementations

- GRDBQuery
- Query
- DynamicProperty Implementations

API Collection

# DynamicProperty Implementations

## Topics

### Instance Methods

`func update()`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-7u3nj)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-8786d)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(constant:)-20bym)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:in:)-2o5mo)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:in:)-8jlgq)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(constant:in:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrappedvalue)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/projectedvalue)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrapper)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-9bg3k)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(_:)-81ae1)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/init(constant:)-1ko9k)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/dynamicproperty-implementations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/constantregion

- GRDBQuery
- QueryableOptions
- constantRegion

Type Property

# constantRegion

By default, the tracked database region is not considered constant, and this prevents some scheduling optimizations. Demanding apps may use this `constantRegion` option when appropriate. Check the documentation of `GRDB.ValueObservation.trackingConstantRegion(_:)` before using this option.

static let constantRegion: QueryableOptions

QueryableOptions.swift

## Discussion

For example:

struct PlayersRequest: ValueObservationQueryable {
static let queryableOptions = QueryableOptions.constantRegion
static let defaultValue: [Player] = []

try Player.fetchAll(db)
}
}

This option only applies to `ValueObservationQueryable` and `PresenceObservationQueryable` types.

## See Also

### Predefined options

`static let async: QueryableOptions`

By default, the initial value is immediately fetched. Use the `async` option when it should be asynchronously fetched.

`static let assertNoFailure: QueryableOptions`

By default, any error that occurs can be accessed using `error` and is otherwise ignored. With this option, errors that happen while accessing the database terminate the app with a fatal error.

- constantRegion
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable/fetch(_:)

#app-main)

- GRDBQuery
- PresenceObservationQueryable
- fetch(\_:)

Instance Method

# fetch(\_:)

Returns the observed value, or nil if it does not exist.

PresenceObservationQueryable.swift

**Required**

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable/queryableoptions-31q1q

- GRDBQuery
- PresenceObservationQueryable
- queryableOptions

Type Property

# queryableOptions

Options for the database observation.

static var queryableOptions: QueryableOptions { get }

PresenceObservationQueryable.swift

**Required** Default implementation provided.

## Discussion

By default:

- The initial value is immediately fetched, right on subscription. This might not be suitable for slow database accesses.

- The tracked database region is not considered constant, which prevents some scheduling optimizations.

See `QueryableOptions` for more options.

See also `QueryObservation` for enabling or disabling database observation.

## Default Implementations

### PresenceObservationQueryable Implementations

`static var queryableOptions: QueryableOptions`

- queryableOptions
- Discussion
- Default Implementations

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presence

- GRDBQuery
- PresenceObservationQueryable
- Presence

Enumeration

# Presence

An enum that with three distinct cases, regarding the presence of a value: `.missing`, `.existing`, or `.gone`. The `.gone` case contains the latest known value.

Presence.swift

# Overview

`Presence` makes it possible to display values on screen, even after they no longer exist. See `PresenceObservationQueryable` for a sample code.

All Combine publishers that publish optional values can be turned into a publisher of `Presence`, with `scanPresence()`.

## Topics

### Enumeration Cases

`case existing(Value)`

The value exists.

`case gone(Value)`

The value no longer exists, but we have its latest value.

`case missing`

The value does not exist, and we don’t have any information about it.

### Instance Properties

`var exists: Bool`

A boolean value indicating whether the value exists.

`var value: Value?`

Returns the value, whether it exists or it is gone.

## Relationships

### Conforms To

- `Swift.Copyable`
- `Swift.Equatable`
- `Swift.Hashable`
- `Swift.Identifiable`
- `Swift.Sendable`

## See Also

### Support

`func scanPresence<Value>() -> Publishers.Scan<Self, Presence<Value>>`

Transforms the upstream publisher of optional values into a publisher of `Presence` that preserves the last non-nil value.

- Presence
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/combine/publisher/scanpresence()

#app-main)

- GRDBQuery
- PresenceObservationQueryable
- scanPresence()

Instance Method

# scanPresence()

Transforms the upstream publisher of optional values into a publisher of `Presence` that preserves the last non-nil value.

GRDBQueryCombine

func scanPresence<Value>() -> Publishers.Scan<Self, Presence<Value>> where Self.Output == Value?

Presence.swift

Available when `Self` is `Publisher`.

## Discussion

For example:

publisher publisher.presence()
| nil | .missing
| 1 | .existing(1)
| 2 | .existing(2)
| nil | .gone(2)
| nil | .gone(2)
| 3 | .existing(3)
v v

## See Also

### Support

`enum Presence`

An enum that with three distinct cases, regarding the presence of a value: `.missing`, `.existing`, or `.gone`. The `.gone` case contains the latest known value.

- scanPresence()
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable/wrappedvalue

- GRDBQuery
- PresenceObservationQueryable
- WrappedValue

Associated Type

# WrappedValue

PresenceObservationQueryable.swift

**Required**

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/constantregion).



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable/fetch(_:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable/queryableoptions-31q1q)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presence)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/combine/publisher/scanpresence())

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/presenceobservationqueryable/wrappedvalue)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable/fetch(_:)

#app-main)

- GRDBQuery
- FetchQueryable
- fetch(\_:)

Instance Method

# fetch(\_:)

Returns the fetched value.

FetchQueryable.swift

**Required**

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable/queryableoptions-34xuk

- GRDBQuery
- FetchQueryable
- queryableOptions

Type Property

# queryableOptions

Options for the database fetch.

static var queryableOptions: QueryableOptions { get }

FetchQueryable.swift

**Required** Default implementation provided.

## Discussion

The default behavior immediately fetches the value, right on subscription. This might not be suitable for slow database accesses.

See `QueryableOptions` for more options.

## Default Implementations

### FetchQueryable Implementations

`static var queryableOptions: QueryableOptions`

- queryableOptions
- Discussion
- Default Implementations

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable/fetch(_:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable/queryableoptions-34xuk)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/async



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/assertnofailure

- GRDBQuery
- QueryableOptions
- assertNoFailure

Type Property

# assertNoFailure

By default, any error that occurs can be accessed using `error` and is otherwise ignored. With this option, errors that happen while accessing the database terminate the app with a fatal error.

static let assertNoFailure: QueryableOptions

QueryableOptions.swift

## See Also

### Predefined options

`static let async: QueryableOptions`

By default, the initial value is immediately fetched. Use the `async` option when it should be asynchronously fetched.

`static let constantRegion: QueryableOptions`

By default, the tracked database region is not considered constant, and this prevents some scheduling optimizations. Demanding apps may use this `constantRegion` option when appropriate. Check the documentation of `GRDB.ValueObservation.trackingConstantRegion(_:)` before using this option.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/init(rawvalue:)

#app-main)

- GRDBQuery
- QueryableOptions
- init(rawValue:)

Initializer

# init(rawValue:)

Inherited from `OptionSet.init(rawValue:)`.

init(rawValue: Int)

QueryableOptions.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/rawvalue

- GRDBQuery
- QueryableOptions
- rawValue

Instance Property

# rawValue

Inherited from `RawRepresentable.rawValue`.

let rawValue: Int

QueryableOptions.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/default

- GRDBQuery
- QueryableOptions
- default

Type Property

# default

The default options.

static let `default`: QueryableOptions

QueryableOptions.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/equatable-implementations

- GRDBQuery
- QueryableOptions
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/optionset-implementations

- GRDBQuery
- QueryableOptions
- OptionSet Implementations

API Collection

# OptionSet Implementations

## Topics

### Initializers

`init()`

### Instance Methods

`func formIntersection(Self)`

`func formSymmetricDifference(Self)`

`func formUnion(Self)`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/setalgebra-implementations

- GRDBQuery
- QueryableOptions
- SetAlgebra Implementations

API Collection

# SetAlgebra Implementations

## Topics

### Initializers

`init(arrayLiteral: Self.Element...)`

### Instance Properties

`var isEmpty: Bool`

### Instance Methods

`func subtract(Self)`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/async)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/constantregion)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/assertnofailure)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/init(rawvalue:))



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/rawvalue)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/default)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/equatable-implementations)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/optionset-implementations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryableoptions/setalgebra-implementations)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/migratingtogrdbquery09-unrestricted-writes

- GRDBQuery
- Migrating To GRDBQuery 0.9
- Migrating an application that directly uses a DatabaseQueue or DatabasePool

Article

# Migrating an application that directly uses a DatabaseQueue or DatabasePool

## Is my application concerned?

If your application defines SwiftUI views that read and write in the database via a raw GRDB connection ( `DatabaseQueue` or `DatabasePool`), and observe the database with the `@Query` property wrapper, then GRDBQuery 0.9 can greatly simplify the your setup.

### Remove the custom environment key

Before the migration, the application defines a custom environment key, as below:

// BEFORE MIGRATION
private struct DatabaseQueueKey: EnvironmentKey {
/// The default dbQueue is an empty in-memory database
static var defaultValue: DatabaseQueue { DatabaseQueue() }
}

extension EnvironmentValues {
var dbQueue: DatabaseQueue {
get { self[DatabaseQueueKey.self] }
set { self[DatabaseQueueKey.self] = newValue }
}
}

@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
.environment(\.dbQueue, /* some DatabaseQueue on disk */)
}
}
}

The application may also define extra `Query` initializers for accessing the `DatabaseQueue` from the custom environment key:

// BEFORE MIGRATION
extension Query where Request.DatabaseContext == DatabaseQueue {
init(_ request: Request) { ... }

init(constant request: Request) { ... }
}

To migrate:

- ✨ Delete the custom environment key.

- ✨ Delete the extra `Query` initializers

- ✨ Register a `DatabaseContext` instead of the raw `DatabaseQueue`:

// AFTER MIGRATION
@main
struct MyApp: App {
var body: some Scene {
WindowGroup {
MyView()
.databaseContext(.readWrite { /* the DatabaseQueue */ })
}
}
}

### Simplify queryable types

Before the migration, the application defines queryable types that feed from a `DatabaseQueue`:

// BEFORE MIGRATION
struct PlayersRequest: Queryable {
static var defaultValue: [Player] { [] }

ValueObservation
.tracking { db in try fetchValue(db) }
.publisher(in: dbQueue, scheduling: .immediate)
.eraseToAnyPublisher()
}

try Player.fetchAll(db)
}
}

- ✨ Simplify queryable types with the convenience protocols (see `ValueObservationQueryable` and its siblings), when possible:

// AFTER MIGRATION
struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

- ✨ For queryable types that can’t use any of the convenience protocols, update the argument of `publisher(in:)` from `DatabaseQueue` to `DatabaseContext`:

// AFTER MIGRATION
struct MyCustomRequest: Queryable {
static var defaultValue: [Player] { [] }

// Read from context.reader instead of dbQueue
}
}

### Migrate views that perform writes

Before the migration, the application defines views that write in the database:

// BEFORE MIGRATION
struct DeletePlayersButton: View {
@Environment(\.dbQueue) var dbQueue

var body: some View {
Button("Delete Players") {
do {
try dbQueue.write {
try Player.deleteAll(db)
}
} catch {
// Handle error
}
}
}
}

- ✨ Replace `dbQueue` with `databaseContext`:

// AFTER MIGRATION
struct DeletePlayersButton: View {
@Environment(\.databaseContext) var databaseContext

var body: some View {
Button("Delete Players") {
do {
try databaseContext.writer.write {
try Player.deleteAll(db)
}
} catch {
// Handle error
}
}
}
}

## See Also

### Focused Migration Guides

Migrating an application that uses a database manager

- Migrating an application that directly uses a DatabaseQueue or DatabasePool
- Is my application concerned?
- Remove the custom environment key
- Simplify queryable types
- Migrate views that perform writes
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/migratingtogrdbquery09-restricted-writes

- GRDBQuery
- Migrating To GRDBQuery 0.9
- Migrating an application that uses a database manager

Article

# Migrating an application that uses a database manager

## Is my application concerned?

In such an application, SwiftUI views read and write in the database via a “database manager” that encapsulates a GRDB connection. Some views access the database with the `@Query` property wrapper.

If the application connects to multiple databases, read this guide for an overview of the benefits of GRDBQuery 0.9, but prefer the techniques described in Custom Database Contexts.

### Use a DatabaseContext

Before the migration, the application defines a custom environment key for the database manager, as below:

// BEFORE MIGRATION
private struct PlayerRepositoryKey: EnvironmentKey {
static let defaultValue = PlayerRepository.empty()
}

extension EnvironmentValues {
var playerRepository: PlayerRepository {
get { self[PlayerRepositoryKey.self] }
set { self[PlayerRepositoryKey.self] = newValue }
}
}

extension View {
/// Sets the `playerRepository` environment value.

environment(\.playerRepository, repository)
}
}

The application may also define extra `Query` initializers for accessing the database manager from the custom environment key:

// BEFORE MIGRATION
extension Query where Request.DatabaseContext == PlayerRepository {
init(_ request: Request) { ... }

init(constant request: Request) { ... }
}

To migrate:

- ✨ Delete the extra `Query` initializers.

- ✨ Expose a read-only access from the database manager:

extension PlayerRepository {
/// Provides a read-only access to the database.
var reader: GRDB.DatabaseReader { writer }
}

- ✨ Set a read-only `DatabaseContext` in the SwiftUI environment:

// AFTER MIGRATION
extension View {
/// Sets both the `playerRepository` (for writes) and `databaseContext`
/// (for `@Query`) environment values.

self
.environment(\.playerRepository, repository)
.databaseContext(.readOnly { repository.reader })
}
}

### Simplify queryable types

Before the migration, the application defines queryable types that feed from the database manager:

// BEFORE MIGRATION
struct PlayersRequest: Queryable {
static var defaultValue: [Player] { [] }

ValueObservation
.tracking { db in try fetchValue(db) }
.publisher(in: repository.reader, scheduling: .immediate)
.eraseToAnyPublisher()
}

try Player.fetchAll(db)
}
}

- ✨ Simplify queryable types with the convenience protocols (see `ValueObservationQueryable` and its siblings), when possible:

// AFTER MIGRATION
struct PlayersRequest: ValueObservationQueryable {
static var defaultValue: [Player] { [] }

- ✨ For queryable types that can’t use any of the convenience protocols, update the argument of `publisher(in:)` from `DatabaseQueue` to `DatabaseContext`:

// AFTER MIGRATION
struct MyCustomRequest: Queryable {
static var defaultValue: [Player] { [] }

// Read from context.reader instead of dbQueue
}
}

See Custom Database Contexts for more details.

## See Also

### Focused Migration Guides

Migrating an application that directly uses a DatabaseQueue or DatabasePool

- Migrating an application that uses a database manager
- Is my application concerned?
- Use a DatabaseContext
- Simplify queryable types
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/query/wrapper/error).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/migratingtogrdbquery09-unrestricted-writes)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/migratingtogrdbquery09-restricted-writes)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable/fetch(_:)

#app-main)

- GRDBQuery
- ValueObservationQueryable
- fetch(\_:)

Instance Method

# fetch(\_:)

Returns the observed value.

ValueObservationQueryable.swift

**Required**

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable/queryableoptions-5c4uu

- GRDBQuery
- ValueObservationQueryable
- queryableOptions

Type Property

# queryableOptions

Options for the database observation.

static var queryableOptions: QueryableOptions { get }

ValueObservationQueryable.swift

**Required** Default implementation provided.

## Discussion

By default:

- The initial value is immediately fetched, right on subscription. This might not be suitable for slow database accesses.

- The tracked database region is not considered constant, which prevents some scheduling optimizations.

See `QueryableOptions` for more options.

See also `QueryObservation` for enabling or disabling database observation.

## Default Implementations

### ValueObservationQueryable Implementations

`static var queryableOptions: QueryableOptions`

- queryableOptions
- Discussion
- Default Implementations

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable/fetch(_:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/valueobservationqueryable/queryableoptions-5c4uu)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/publisher(in:)-169me

-169me#app-main)

- GRDBQuery
- Queryable
- publisher(in:)

Instance Method

# publisher(in:)

Returns a Combine publisher of database values.

@MainActor

Queryable.swift

**Required** Default implementations provided.

## Parameters

`database`

Provides access to the database.

## Discussion

The returned publisher must publish its values and completion on the main actor.

## Default Implementations

## See Also

### Database Values

`static var defaultValue: Self.Value`

The default value, used until the Combine publisher publishes its initial value.

**Required** Default implementation provided.

- publisher(in:)
- Parameters
- Discussion
- Default Implementations
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/defaultvalue-6vuzw

- GRDBQuery
- Queryable
- defaultValue

Type Property

# defaultValue

The default value, used until the Combine publisher publishes its initial value.

@MainActor
static var defaultValue: Self.Value { get }

Queryable.swift

**Required** Default implementation provided.

## Discussion

The default value is unused if the publisher successfully publishes its initial value right on subscription.

## Default Implementations

## See Also

### Database Values

Returns a Combine publisher of database values.

**Required** Default implementations provided.

- defaultValue
- Discussion
- Default Implementations
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/context

- GRDBQuery
- Queryable
- Context

Associated Type

# Context

The type that provides database access.

associatedtype Context = DatabaseContext

Queryable.swift

**Required**

## Discussion

By default, it is `DatabaseContext`.

Generally speaking, any type can fit, as long as the `Queryable` type can build a Combine publisher from an instance of this type, in the `publisher(in:)` method.

It may be a `GRDB.DatabaseQueue`, or your custom database manager: see Custom Database Contexts for more guidance.

## See Also

### Associated Types

`associatedtype ValuePublisher : Publisher`

The type of the Combine publisher of database values, returned from `publisher(in:)`.

`associatedtype Value`

The type of the published values.

- Context
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/valuepublisher

- GRDBQuery
- Queryable
- ValuePublisher

Associated Type

# ValuePublisher

The type of the Combine publisher of database values, returned from `publisher(in:)`.

associatedtype ValuePublisher : Publisher

Queryable.swift

**Required**

## See Also

### Associated Types

`associatedtype Context = DatabaseContext`

The type that provides database access.

`associatedtype Value`

The type of the published values.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/value

- GRDBQuery
- Queryable
- Value

Associated Type

# Value

The type of the published values.

associatedtype Value where Self.Value == Self.ValuePublisher.Output

Queryable.swift

**Required**

## See Also

### Associated Types

`associatedtype Context = DatabaseContext`

The type that provides database access.

`associatedtype ValuePublisher : Publisher`

The type of the Combine publisher of database values, returned from `publisher(in:)`.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/publisher(in:)-169me)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/defaultvalue-6vuzw),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/customdatabasecontexts)).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/context)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/valuepublisher)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/publisher(in:)-169me).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/value)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryable/defaultvalue-6vuzw)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/notconnected

- GRDBQuery
- DatabaseContext
- notConnected

Type Property

# notConnected

A `DatabaseContext` that throws `DatabaseContextError.notConnected` on every database access.

static var notConnected: DatabaseContext { get }

DatabaseContext.swift

## Discussion

The `SwiftUI/EnvironmentValues/databaseContext` environment key contains such a database context unless the application replaces it.

## See Also

### Creating A DatabaseContext

Creates a read-only `DatabaseContext` from an existing database connection.

- notConnected
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/notconnected

- GRDBQuery
- DatabaseContextError
- DatabaseContextError.notConnected

Case

# DatabaseContextError.notConnected

Database is not connected.

case notConnected

DatabaseContext.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/reader

- GRDBQuery
- DatabaseContext
- reader

Instance Property

# reader

Inherited from `TopLevelDatabaseReader.reader`.

@MainActor
var reader: any DatabaseReader { get throws }

DatabaseContext.swift

## See Also

### Accessing the database

`var writer: any DatabaseWriter`

Returns a database writer.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/writer

- GRDBQuery
- DatabaseContext
- writer

Instance Property

# writer

Returns a database writer.

var writer: any DatabaseWriter { get throws }

DatabaseContext.swift

## See Also

### Accessing the database

`var reader: any DatabaseReader`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/topleveldatabasereader-implementations

- GRDBQuery
- DatabaseContext
- TopLevelDatabaseReader Implementations

API Collection

# TopLevelDatabaseReader Implementations

## Topics

### Instance Properties

`var reader: any DatabaseReader`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/notconnected)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/notconnected)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/reader)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/writer)



---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/readwrite(_:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontext/topleveldatabasereader-implementations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/anydatabasereader

- GRDBQuery
- GRDB
- AnyDatabaseReader

Extended Class

# AnyDatabaseReader

GRDBQueryGRDB

extension AnyDatabaseReader

## Topics

## Relationships

### Conforms To

- `Swift.Copyable`
- `TopLevelDatabaseReader`

- AnyDatabaseReader
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasepool

- GRDBQuery
- GRDB
- DatabasePool

Extended Class

# DatabasePool

GRDBQueryGRDB

extension DatabasePool

## Topics

## Relationships

### Conforms To

- `Swift.Copyable`
- `TopLevelDatabaseReader`

- DatabasePool
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasequeue

- GRDBQuery
- GRDB
- DatabaseQueue

Extended Class

# DatabaseQueue

GRDBQueryGRDB

extension DatabaseQueue

## Topics

## Relationships

### Conforms To

- `Swift.Copyable`
- `TopLevelDatabaseReader`

- DatabaseQueue
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasesnapshot

- GRDBQuery
- GRDB
- DatabaseSnapshot

Extended Class

# DatabaseSnapshot

GRDBQueryGRDB

extension DatabaseSnapshot

## Topics

## Relationships

### Conforms To

- `Swift.Copyable`
- `TopLevelDatabaseReader`

- DatabaseSnapshot
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasesnapshotpool

- GRDBQuery
- GRDB
- DatabaseSnapshotPool

Extended Class

# DatabaseSnapshotPool

GRDBQueryGRDB

extension DatabaseSnapshotPool

## Topics

## Relationships

### Conforms To

- `Swift.Copyable`
- `TopLevelDatabaseReader`

- DatabaseSnapshotPool
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/anydatabasereader)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasepool)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasequeue)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasesnapshot)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/grdb/databasesnapshotpool)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/topleveldatabasereader/reader-6s78b

- GRDBQuery
- TopLevelDatabaseReader
- reader

Instance Property

# reader

Provides a read-only access to the database.

@MainActor
var reader: any DatabaseReader { get throws }

TopLevelDatabaseReader.swift

**Required** Default implementation provided.

## Default Implementations

### TopLevelDatabaseReader Implementations

`var reader: any DatabaseReader`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/topleveldatabasereader/reader-6s78b)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/readonly

- GRDBQuery
- DatabaseContextError
- DatabaseContextError.readOnly

Case

# DatabaseContextError.readOnly

Write access is not available.

case readOnly

DatabaseContext.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/equatable-implementations

- GRDBQuery
- DatabaseContextError
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/error-implementations

- GRDBQuery
- DatabaseContextError
- Error Implementations

API Collection

# Error Implementations

## Topics

### Instance Properties

`var localizedDescription: String`

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/readonly)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/equatable-implementations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/error-implementations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftuicore/view

- GRDBQuery
- SwiftUICore
- View

Extended Protocol

# View

GRDBQuerySwiftUICore

extension View

## Topics

### Instance Methods

Sets the database context in the SwiftUI environment of the `View`.

Controls when the `@Query` property wrappers observe their requests, in this view.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftuicore/environmentvalues

- GRDBQuery
- SwiftUICore
- EnvironmentValues

Extended Structure

# EnvironmentValues

GRDBQuerySwiftUICore

extension EnvironmentValues

## Topics

### Instance Properties

`var databaseContext: DatabaseContext`

The database context used for `@Query` and other database operations within the SwiftUI environment.

`var queryObservationEnabled: Bool`

A Boolean value that indicates whether `@Query` property wrappers are observing their requests.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftuicore/view)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/swiftuicore/environmentvalues)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/databasecontexterror/readonly).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/fetchqueryable),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/topleveldatabasereader),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/always

- GRDBQuery
- QueryObservation
- QueryObservation.always

Case

# QueryObservation.always

Requests are always observed.

case always

QueryObservation.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/onappear

- GRDBQuery
- QueryObservation
- QueryObservation.onAppear

Case

# QueryObservation.onAppear

Request observation starts and stops according to the `onAppear` and `onDisappear` View events.

case onAppear

QueryObservation.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/onrender

- GRDBQuery
- QueryObservation
- QueryObservation.onRender

Case

# QueryObservation.onRender

Request observation starts on the first `body` rendering of the view, and is later stopped and restarted according to the `onAppear` and `onDisappear` View events.

case onRender

QueryObservation.swift

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/equatable-implementations

- GRDBQuery
- QueryObservation
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/always)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/onappear)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdbquery/0.11.0/documentation/grdbquery/queryobservation/onrender)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

