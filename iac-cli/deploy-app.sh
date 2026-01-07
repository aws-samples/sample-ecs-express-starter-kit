#Create the roles with ECS trust policies
aws iam create-role --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",		 	 	 
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole",
            }
        ]
    }'

aws iam create-role --role-name ecsInfrastructureRoleForExpressServices \ 
    --assume-role-policy-document '{
        "Version": "2012-10-17",		 	 	 
        "Statement": [
            {
                "Sid": "AllowAccessInfrastructureForECSExpressServices",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' 


aws iam attach-role-policy --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices




aws ecs create-express-gateway-service \
    --execution-role-arn arn:aws:iam::123456789012:role/ecsTaskExecutionRole \
    --infrastructure-role-arn arn:aws:iam::123456789012:role/ecsInfrastructureRoleForExpressServices \
    --primary-container \
        '{"image"="public.ecr.aws/p7b6k2h9/mod-app:0.0.5", \
        “containerPort"=8080, \
        “environment"=[{“name"=“ENV","value"=“production"},{“name"=“DEBUG","value"=“false"}]}' \
    --service-name "my-web-app" \
    --cpu 2 \
    --memory 4 \
    --health-check-path "/health" \
    --scaling-target '{“minTaskCount"=1,"maxTaskCount"=5}' \
    --monitor-resources