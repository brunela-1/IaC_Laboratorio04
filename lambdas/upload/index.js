const AWS = require("aws-sdk");
const s3 = new AWS.S3();
 
exports.handler = async (event) => {
  try {
    console.log("Upload Lambda ejecutándose");
    console.log("EVENT:", JSON.stringify(event, null, 2));
 
    if (!event.body) {
      console.error("Body vacío");
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Body vacío" }),
      };
    }
 
    const body = typeof event.body === "string" 
      ? JSON.parse(event.body) 
      : event.body;
 
    if (!body.image) {
      console.error("No viene 'image' en el body");
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Falta el campo 'image' en base64" }),
      };
    }
 
    const buffer = Buffer.from(body.image, "base64");
    console.log(`Buffer creado: ${buffer.length} bytes`);
 
    if (buffer.length > 10 * 1024 * 1024) {
      console.error("Imagen muy grande");
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Imagen muy grande. Max 10 MB" }),
      };
    }
 
    const bucket = process.env.S3_BUCKET;
    if (!bucket) {
      console.error("S3_BUCKET no configurado");
      throw new Error("S3_BUCKET no está configurado en variables de entorno");
    }
 
    const timestamp = Date.now();
    const filename = body.filename || `image-${timestamp}.png`;
    const key = `uploads/${timestamp}-${filename}`;
 
    console.log(`Subiendo a S3: s3://${bucket}/${key}`);
 
    const params = {
      Bucket: bucket,
      Key: key,
      Body: buffer,
      ContentType: body.contentType || "image/png",
    };
 
    const result = await s3.putObject(params).promise();
    console.log("Imagen subida exitosamente:", result);
 
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "Imagen subida exitosamente",
        bucket: bucket,
        key: key,
        size: buffer.length,
      }),
    };
 
  } catch (err) {
    console.error("ERROR LAMBDA UPLOAD:", err);
 
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        error: "Error interno del servidor",
        message: err.message,
      }),
    };
  }
};