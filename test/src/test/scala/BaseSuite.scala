import com.typesafe.scalalogging.LazyLogging
import dev.mongocamp.driver.DocumentIncludes
import dev.mongocamp.driver.mongodb._
import dev.mongocamp.driver.mongodb.bson.codecs.CustomCodecProvider
import dev.mongocamp.driver.mongodb.database.{DatabaseProvider, MongoConfig}
import org.bson.codecs.configuration.CodecRegistries.{fromProviders, fromRegistries}
import org.mongodb.scala.MongoClient.DEFAULT_CODEC_REGISTRY
import org.mongodb.scala.MongoCommandException
import scala.jdk.CollectionConverters._

class BaseSuite extends munit.FunSuite with LazyLogging with DocumentIncludes{

  lazy val mongoConfig: MongoConfig = {
    val dbPort = loadEnvValue("MONGODB_PORT", (key: String) => key.toInt).getOrElse(MongoConfig.DefaultPort)
    val dbUser = loadEnvValue("MONGODB_USERNAME", (key: String) => key)
    val dbPassword = loadEnvValue("MONGODB_PWD", (key: String) => key).filterNot(_.equalsIgnoreCase("NONE"))
    val mongodbReplSet = loadEnvValue("MONGODB_REPLICA_SET", (key: String) => key).filter(_.trim.nonEmpty)
    System.getenv().asScala.foreach { case (key, value) =>
      println(s"ENV: [$key] $value")
    }
    System.getProperties.asScala.foreach { case (key, value) =>
      println(s"Properties: [$key] $value")
    }
    println("***************************************************")
    println(s"Port:       $dbPort")
    println(s"User:       $dbUser")
    println(s"Password:   $dbPassword")
    println(s"ReplicaSet: $mongodbReplSet")
    println("***************************************************")
    MongoConfig(
      "admin",
      port = dbPort,
      userName = dbUser,
      password = dbPassword
    )
  }

  lazy val databaseProvider: DatabaseProvider = {
    val dbProvider = DatabaseProvider(mongoConfig, fromRegistries(DEFAULT_CODEC_REGISTRY, fromProviders(CustomCodecProvider())))
    dbProvider
  }

  private val collectionName = "hello"

  test(s"insert some data to collection `$collectionName`") {
    val dao = databaseProvider.dao(collectionName)
    val insertResult = dao.insertOne(Map("hello" -> "world")).result(60)
    assertEquals(insertResult.wasAcknowledged(), true)
  }

  test(s"read some data to collection `$collectionName`") {
    val dao = databaseProvider.dao(collectionName)
    val countResult = dao.count().result(60)
    assertEquals(countResult, 1L)
  }

  test(s"check is in replica set") {
    val replSet : Option[String] = loadEnvValue("MONGODB_REPLICA_SET", (key: String) => key).filter(_.trim.nonEmpty)
    val isReplSetActive : Boolean = replSet.nonEmpty
    try {
      val commandResponse = databaseProvider.runCommand(Map("replSetGetStatus" -> 1)).result(60)
      assertEquals(isReplSetActive, true, "isReplSetActive is not true")
      assertEquals(replSet.get, commandResponse.getStringValue("set"))
    } catch {
      case e: MongoCommandException =>
        val noReplication = e.getErrorCode == 76
        assertEquals(noReplication, !isReplSetActive, "noReplication enabled but isReplSetActive is true")
    }
  }

  override def beforeAll(): Unit = {
    databaseProvider.dao(collectionName).drop().result(60)
  }

  private def loadEnvValue[E <: Any](systemSettingKey: String, castStringToValue: String => E): Option[E] = {
    val envSetting = System.getenv(systemSettingKey)
    if (envSetting != null && !"".equalsIgnoreCase(envSetting.trim)) {
      Some(castStringToValue(envSetting))
    }
    else {
      val propertySetting = System.getProperty(systemSettingKey)
      if (propertySetting != null && !"".equalsIgnoreCase(propertySetting.trim)) {
        Some(castStringToValue(propertySetting))
      }
      else {
        None
      }
    }
  }

}
