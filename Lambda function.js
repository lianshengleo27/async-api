import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  ScanCommand,
  PutCommand,
  GetCommand,
  DeleteCommand,
} from "@aws-sdk/lib-dynamodb";
import crypto from "crypto";
import { ECSClient, RunTaskCommand } from '@aws-sdk/client-ecs';

const client = new DynamoDBClient({});
const dynamo = DynamoDBDocumentClient.from(client);
const tableName = "pointcloud";

export const handler = async (event, context) => {
  let body;
  let statusCode = 200;
  let requestJson;
  let task_id;
  const headers = {
    "Content-Type": "application/json",
  };

  try {
    switch (event.routeKey) {
      case "POST /pointcloud":
        const acceptedAt = new Date();
        const acceptedAtUtc = acceptedAt.toUTCString();
        requestJson = JSON.parse(event.body);
        task_id = crypto.randomBytes(16).toString("hex").substring(0, 16)
        await dynamo.send(
          new PutCommand({
            TableName: tableName,
            Item: {
              id: task_id,
              status: "IN_PROGRESS",
              accepted_at: acceptedAtUtc,
              started_at: null,
              finished_at:  null,
              result: null
            },
          })
        );
        body = {
          task_id: task_id
        };
        
        const ecs = new ECSClient({region: process.env.AWS_REGION})
        const ecsParams = {
          cluster: process.env.AWS_ECS_CLUSTER,
          taskDefinition: process.env.AWS_ECS_TASK_DEFINITION,
          count: 1,
          enableExecuteCommand: true,
          launchType: "FARGATE",
          networkConfiguration: {
            awsvpcConfiguration: {
              subnets: process.env.AWS_ECS_SUBNET.split(","),
              securityGroups: process.env.AWS_ECS_SECURITY_GROUP.split(","),
              assignPublicIp: "ENABLED",

            }
          },
          overrides: {
            containerOverrides: [
              {
                name: process.env.AWS_ECS_CONTAINER_NAME,
                environment: [
                  {name:"DOWNLOAD_URL", value: requestJson.download_url},
                  {name:"FILE_NAME", value: requestJson.file_name},
                  {name:"CC_OPTION", value: requestJson.command},
                  {name:"IMAGE_UPLOAD_API_URL", value: process.env.IMAGE_UPLOAD_API_URL},
                  {name:"TASK_ID", value: task_id},
                  {name:"POINT_CLOUD_API_URL", value: process.env.POINT_CLOUD_API_URL},
                ]
              }
            ]
          }
        }
        console.log(JSON.stringify(ecsParams))
        try {
          await ecs.send(new RunTaskCommand(ecsParams))
        }
        catch(err){
          console.log(err.message)
          const response  = {
            statusCode:500,
            body: JSON.stringify({
              error:{
                message: "internal server error"
              }
            })
          }
          return response
        }
        break;
      case "PUT /pointcloud/tasks/{id}":
        const changedAt = new Date();
        const changedAtUtc = changedAt.toUTCString();
        requestJson = JSON.parse(event.body);
        task_id = event.pathParameters.id;
        const result_id = crypto.randomBytes(16).toString("hex").substring(0, 16)
        body = await dynamo.send(
          new GetCommand({
            TableName: tableName,
            Key: {
              id: task_id,
            },
          })
        );
        body = body.Item;

        switch (requestJson.type) {
          case "start":
            await dynamo.send(
              new PutCommand({
                TableName: tableName,
                Item: {
                  id: task_id,
                  status: "IN_PROGRESS",
                  accepted_at: body.accepted_at,
                  started_at: changedAtUtc,
                  finished_at: null,
                  result: null
                },
              })
            );
            break;
          case "finish":
            await dynamo.send(
              new PutCommand({
                TableName: tableName,
                Item: {
                  id: task_id,
                  status: "SUCCEEDED",
                  accepted_at: body.accepted_at,
                  started_at: body.started_at,
                  finished_at: changedAtUtc,
                  result: {
                    result_id: result_id
                  }
                },
              })
            );
            await dynamo.send(
              new PutCommand({
                TableName: tableName,
                Item: {
                  id: result_id,
                  download_url: "https://async-api-for-pointcloud.s3.ap-northeast-1.amazonaws.com/" + requestJson.path 
                },
              })
            );
            break;
        }
        break;
      case "GET /pointcloud/tasks/{id}":
        body = await dynamo.send(
          new GetCommand({
            TableName: tableName,
            Key: {
              id: event.pathParameters.id,
            },
          })
        );
        body = body.Item;
        break;
      case "GET /pointcloud/results/{id}":
        body = await dynamo.send(
          new GetCommand({
            TableName: tableName,
            Key: {
              id: event.pathParameters.id,
            },
          })
        );
        body = body.Item;
        break;
      default:
        throw new Error(`Unsupported route: "${event.routeKey}"`);
    }
  } catch (err) {
    statusCode = 400;
    body = err.message;
  } finally {
    body = JSON.stringify(body);
  }

  return {
    statusCode,
    body,
    headers,
  };
};