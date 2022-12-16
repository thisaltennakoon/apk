//
// Copyright (c) 2022, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
import ballerina/websocket;
import ballerina/lang.value;
import runtime_domain_service.model as model;
import ballerina/log;

map<map<model:K8sAPI>> serviceMappings = {};
string serviceMappingResourceVersion = "";
map<model:K8sServiceMapping> k8sServiceMappings = {};
websocket:Client|error|() serviceMappingClient = ();

class ServiceMappingTask {
    function init(string resourceVersion) {
        serviceMappingClient = getServiceMappingClient(serviceMappingResourceVersion);
    }

    public function startListening() returns error? {

        worker WatchServiceMappingThread {
            while true {
                do {
                    websocket:Client|error|() apiClientResult = serviceMappingClient;
                    if apiClientResult is websocket:Client {
                        boolean connectionOpen = apiClientResult.isOpen();
                        if !connectionOpen {
                            log:printDebug("Websocket Client connection closed conectionId: " + apiClientResult.getConnectionId() + " state: " + connectionOpen.toString());
                            serviceMappingClient = getServiceMappingClient(serviceMappingResourceVersion);
                            websocket:Client|error|() retryClient = serviceMappingClient;
                            if retryClient is websocket:Client {
                                log:printDebug("Reinitializing client..");
                                connectionOpen = retryClient.isOpen();
                                log:printDebug("Intializd new Client Connection conectionId: " + retryClient.getConnectionId() + " state: " + connectionOpen.toString());
                                _ = check readServiceMappingEvent(retryClient);
                            } else if retryClient is error {
                                log:printError("error while reading message", retryClient);
                            }
                        } else {
                            _ = check readServiceMappingEvent(apiClientResult);
                        }

                    } else if apiClientResult is error {
                        log:printError("error while reading message", apiClientResult);
                    }
                } on fail var e {
                    log:printError("Unable to read api messages", e);
                }
            }
        }
    }
}

public function getServiceMappingClient(string resourceVersion) returns websocket:Client|error|() {
    string requestURl = "wss://" + runtimeConfiguration.k8sConfiguration.host + "/apis/dp.wso2.com/v1alpha1/watch/servicemappings";
    if resourceVersion.length() > 0 {
        requestURl = requestURl + "?resourceVersion=" + resourceVersion.toString();
    }
    return new (requestURl,
    auth = {
        token: token
    },
        secureSocket = {
        cert: caCertPath
    }
    );
}

function setServiceMappingResourceVersion(string resourceVersionValue) {
    serviceMappingResourceVersion = resourceVersionValue;
}

function readServiceMappingEvent(websocket:Client apiWebsocketClient) returns error? {
    boolean connectionOpen = apiWebsocketClient.isOpen();
    log:printDebug("Using Client Connection conectionId: " + apiWebsocketClient.getConnectionId() + " state: " + connectionOpen.toString());
    if !connectionOpen {
        return error("connection closed");
    }
    string|error message = check apiWebsocketClient->readMessage();
    if message is string {
        log:printDebug(message);
        json value = check value:fromJsonString(message);
        string eventType = <string>check value.'type;
        json eventValue = <json>check value.'object;
        json metadata = <json>check eventValue.metadata;
        string latestResourceVersion = <string>check metadata.resourceVersion;
        setServiceMappingResourceVersion(latestResourceVersion);
        json clonedEvent = eventValue.cloneReadOnly();
        model:K8sServiceMapping|error serviceMapping = <model:K8sServiceMapping>clonedEvent;
        if serviceMapping is model:K8sServiceMapping {
            if serviceMapping.metadata.namespace == getNameSpace(runtimeConfiguration.apiCreationNamespace) {
                if eventType == "ADDED" {
                    addServiceMapping(serviceMappings, serviceMapping);
                } else if (eventType == "MODIFIED") {
                    deleteServiceMapping(serviceMappings, serviceMapping);
                    addServiceMapping(serviceMappings, serviceMapping);
                } else if (eventType == "DELETED") {
                    deleteServiceMapping(serviceMappings, serviceMapping);
                }
            }
        } else {
            log:printError("error while converting");
        }
    } else {
        log:printError("error while reading message", message);
    }

}

function addServiceMapping(map<map<model:K8sAPI>> serviceMappings, model:K8sServiceMapping serviceMapping) {
    k8sServiceMappings[serviceMapping.metadata.uid ?: ""] = serviceMapping;
}

function deleteServiceMapping(map<map<model:K8sAPI>> serviceMappings, model:K8sServiceMapping serviceMapping) {
    _ = k8sServiceMappings.remove(serviceMapping.metadata.uid ?: "");
}

function putAllServiceMappings(json[] events) returns error? {
    foreach json event in events {
        json clonedEvent = event.cloneReadOnly();
        model:K8sServiceMapping|error serviceMapping = trap <model:K8sServiceMapping>clonedEvent;
        if serviceMapping is model:K8sServiceMapping {
            addServiceMapping(serviceMappings, serviceMapping);
        }
    }
}

function retrieveAPIMappingsForService(Service serviceEntry) returns model:K8sAPI[] {
    string[] keys = k8sServiceMappings.keys();
    model:K8sAPI[] apis = [];
    foreach string key in keys {
        model:K8sServiceMapping serviceMapping = k8sServiceMappings.get(key);
        model:ServiceReference serviceRef = serviceMapping.spec.serviceRef;
        if (serviceRef.name == serviceEntry.name && serviceRef.namespace == serviceEntry.namespace) {
            model:APIReference apiRef = serviceMapping.spec.apiRef;
            model:K8sAPI? k8sAPI = getAPIByNameAndNamespace(apiRef.name, apiRef.namespace);
            if k8sAPI is model:K8sAPI {
                apis.push(k8sAPI);
            }
        }
    }
    return apis;
}

function retrieveServiceMappingsForAPI(model:K8sAPI api) returns model:K8sServiceMapping[] {
    string[] keys = k8sServiceMappings.keys();
    model:K8sServiceMapping[] serviceMappings = [];
    foreach string key in keys {
        model:K8sServiceMapping serviceMapping = k8sServiceMappings.get(key);
        model:APIReference apiRef = serviceMapping.spec.apiRef;
        if (apiRef.name == api.k8sName && apiRef.namespace == api.namespace) {
            serviceMappings.push(serviceMapping);
        }
    }
    return serviceMappings;
}
