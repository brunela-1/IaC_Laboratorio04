const AWS = require("aws-sdk");
const s3 = new AWS.S3();
const sharp = require("sharp");

exports.handler = async (event) => {
  try {
    console.log("Crop Lambda ejecutándose");

    for (const record of event.Records) {
      const body = JSON.parse(record.body);

      const bucket = body.Records[0].s3.bucket.name;
      const key = body.Records[0].s3.object.key;

      const image = await s3
        .getObject({
          Bucket: bucket,
          Key: key,
        })
        .promise();

      const resized = await sharp(image.Body)
        .resize(40, 40)
        .png()
        .toBuffer();

      const newKey = key.replace("uploads/", "processed/");

      await s3
        .putObject({
          Bucket: bucket,
          Key: newKey,
          Body: resized,
          ContentType: "image/png",
        })
        .promise();

      console.log("Imagen procesada:", newKey);
    }

    return {
      statusCode: 200,
      body: "Procesamiento completado",
    };
  } catch (error) {
    console.error(error);

    return {
      statusCode: 500,
      body: "Error en procesamiento",
    };
  }
};