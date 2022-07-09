import com.typesafe.scalalogging.LazyLogging
import dev.mongocamp.driver.DocumentIncludes
import dev.mongocamp.driver.mongodb._
import dev.mongocamp.driver.mongodb.bson.codecs.CustomCodecProvider
import dev.mongocamp.driver.mongodb.database.{DatabaseProvider, MongoConfig}
import org.bson.codecs.configuration.CodecRegistries.{fromProviders, fromRegistries}
import org.mongodb.scala.MongoClient.DEFAULT_CODEC_REGISTRY
import org.mongodb.scala.MongoCommandException

class BaseSuite extends munit.FunSuite with LazyLogging with DocumentIncludes{

  lazy val mongoConfig: MongoConfig = {
    val dbPort = loadEnvValue("mongodb-port", (key: String) => key.toInt).getOrElse(MongoConfig.DefaultPort)
    val dbUser = loadEnvValue("mongodb-username", (key: String) => key)
    val dbPassword = loadEnvValue("mongodb-pwd", (key: String) => key).filterNot(_.equalsIgnoreCase("NONE"))
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
    val insertResult = dao.insertOne(Map("hello" -> "world")).result()
    assertEquals(insertResult.wasAcknowledged(), true)
  }

  test(s"read some data to collection `$collectionName`") {
    val dao = databaseProvider.dao(collectionName)
    val countResult = dao.count().result()
    assertEquals(countResult, 1L)
  }

  test(s"check is in replica set") {
    val replSet : Option[String] = loadEnvValue("mongodb-replica-set", (key: String) => key).filter(_.trim.nonEmpty)
    val isReplSetActive : Boolean = replSet.nonEmpty
    try {
      val commandResponse = databaseProvider.runCommand(Map("replSetGetStatus" -> 1)).result()
      assertEquals(isReplSetActive, true, "isReplSetActive is not true")
      assertEquals(replSet.get, commandResponse.getStringValue("set"))
    } catch {
      case e: MongoCommandException =>
        val noReplication = e.getErrorCode == 76
        assertEquals(noReplication, !isReplSetActive, "noReplication enabled but isReplSetActive is true")
    }
  }

  override def beforeAll(): Unit = {
    databaseProvider.dao(collectionName).drop().result()
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
