Test / parallelExecution := false

IntegrationTest / parallelExecution := false

Test / scalacOptions ++= Seq("-Yrangepos")

// Test
libraryDependencies += "org.scalameta" %% "munit" % "1.1.0" % Test

libraryDependencies += "dev.mongocamp" %% "mongodb-driver" % "2.8.1" % Test
