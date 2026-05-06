const AWS = require("aws-sdk");
const s3 = new AWS.S3();

exports.handler = async (event) => {
  try {
    console.log("Upload Lambda ejecutándose");

    const body = JSON.parse(event.body);

    const buffer = Buffer.from(body.image, "base64");

    const params = {
      Bucket: process.env.S3_BUCKET,
      Key: `uploads/${Date.now()}.png`,
      Body: buffer,
      ContentType: "image/png",
    };

    await s3.putObject(params).promise();

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Imagen subida correctamente",
      }),
    };
  } catch (error) {
    console.error(error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error al subir imagen",
      }),
    };
  }
};