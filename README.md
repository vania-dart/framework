
# Introduction

Vania is a robust backend framework designed for building high-performance web applications using Dart. With its straightforward approach and powerful features, Vania streamlines the development process for both beginners and experienced developers alike.

## Features

✅ ***Scalability***: Built to handle high traffic, Vania effortlessly scales alongside your application's growth.

✅ ***Developer-Friendly***: Enjoy an intuitive API and clear documentation, making web application development a breeze.

✅ ***Simple Routing***: Define and manage routes effortlessly with Vania's efficient routing system, ensuring robust application architecture.

✅ ***ORM Support***: Interact seamlessly with databases using Vania's powerful ORM system, simplifying data management.

✅ ***Request Data Validation***: Easily validate incoming request data to maintain data integrity and enhance security.

✅ ***Database Migration***: Manage and apply schema changes with ease using Vania's built-in database migration support.

✅ ***WebSocket***: Enable real-time communication between server and clients with WebSocket support, enhancing user experience.

✅ ***Command-Line Interface (CLI)***: Streamline development tasks with Vania's simple CLI, offering commands for creating migrations, generating models, and more.

Experience the simplicity and power of Vania for your next web application project

Check out the documentation here: [Vania Dart Documentation](https://vdart.dev)

# Quick Start 🚀

Ensure that you have the [Dart SDK](https://dart.dev) installed on your machine.

## Installing 🧑‍💻

```shell
# 📦 Install the vania cli from pub.dev
dart pub global activate vania_cli
```

## Creating a Project ✨

Use the `vania create` command to create a new project.

```shell
# 🚀 Create a new project called "blog"
vania create blog
```

## Start the Dev Server 🏁

Open the newly created project and start the development server.

```shell
# 🏁 Start the dev server
vania serve
```

You can also include the `--vm` flag to enable VM service.

## Create a Production Build 📦

Create a production build:

```shell
# 📦 Create a production build
vania build
```

For production use, deploy using the provided `Dockerfile` and `docker-compose.yml` files to deploy anywhere.

Example CRUD API Project [Github](https://github.com/vania-dart/example)
