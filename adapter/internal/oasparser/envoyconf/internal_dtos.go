/*
 *  Copyright (c) 2022, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

package envoyconf

import (
	"github.com/wso2/apk/adapter/internal/oasparser/model"
	dpv1alpha1 "github.com/wso2/apk/adapter/internal/operator/apis/dp/v1alpha1"
)

// routeCreateParams is the DTO used to provide information to the envoy route create function
type routeCreateParams struct {
	organizationID               string
	title                        string
	version                      string
	apiType                      string
	xWSO2BasePath                string
	vHost                        string
	endpointBasePath             string
	resource                     *model.Resource
	clusterName                  string
	routeConfig                  *model.EndpointConfig
	authHeader                   string
	requestInterceptor           map[string]model.InterceptEndpoint
	responseInterceptor          map[string]model.InterceptEndpoint
	corsPolicy                   *model.CorsConfig
	passRequestPayloadToEnforcer bool
	isDefaultVersion             bool
	apiLevelRateLimitPolicy      *model.RateLimitPolicy
	apiProperty                  *dpv1alpha1.APIProperty
}

// RatelimitCriteria criterias of rate limiting
type ratelimitCriteria struct {
	level                string
	organizationID       string
	vHost                string
	basePathForRLService string
}
