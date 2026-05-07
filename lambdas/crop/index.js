const AWS = require("aws-sdk");
const s3 = new AWS.S3();
const sharp = require("sharp");

exports.handler = async (event) => {
  console.log("Crop Lambda ejecutándose");
  console.log("EVENT:", JSON.stringify(event, null, 2));

  const batchItemFailures = [];

  try {
    for (const record of event.Records) {
      try {
        await processRecord(record);
      } catch (error) {
        console.error(`Error procesando record ${record.messageId}:`, error);
        batchItemFailures.push({ itemIdentifier: record.messageId });
      }
    }

    return { batchItemFailures };

  } catch (error) {
    console.error("ERROR GENERAL:", error);
    throw error;
  }
};

async function processRecord(record) {
  console.log("Procesando mensaje SQS:", record.messageId);

  const message = JSON.parse(record.body);
  console.log("MESSAGE BODY:", JSON.stringify(message, null, 2));

  if (!message.Records || message.Records.length === 0) {
    console.log("No hay Records en el mensaje");
    return;
  }

  const s3Event = message.Records[0];
  const bucket = s3Event.s3.bucket.name;
  const key = decodeURIComponent(s3Event.s3.object.key.replace(/\+/g, " "));

  console.log(`Descargando imagen: s3://${bucket}/${key}`);

  const imageData = await s3.getObject({
    Bucket: bucket,
    Key: key,
  }).promise();

  console.log(`Imagen descargada: ${imageData.Body.length} bytes`);

  console.log("Procesando imagen...");
  
  const circleSvg = `
    <svg width="40" height="40">
      <circle cx="20" cy="20" r="20" fill="white"/>
    </svg>
  `;

  const resizedImage = await sharp(imageData.Body)
    .resize(40, 40, {
      fit: "cover",
      position: "center"
    })
    .composite([
      {
        input: Buffer.from(circleSvg),
        blend: "dest-in"
      }
    ])
    .png()
    .toBuffer();

  console.log(`Imagen procesada: ${resizedImage.length} bytes`);

  const originalFilename = key.split("/").pop();
  const filenameWithoutExt = originalFilename.split(".")[0];
  const newKey = `processed/${filenameWithoutExt}_circular.png`;

  console.log(`Subiendo imagen procesada: s3://${bucket}/${newKey}`);

  await s3.putObject({
    Bucket: bucket,
    Key: newKey,
    Body: resizedImage,
    ContentType: "image/png",
    Metadata: {
      originalKey: key,
      processedAt: new Date().toISOString()
    }
  }).promise();

  console.log("Imagen procesada y subida exitosamente");
}