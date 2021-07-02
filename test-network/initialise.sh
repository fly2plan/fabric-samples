#!/bin/bash

#A script that executes the commands to initialise the test network (https://hyperledger-fabric.readthedocs.io/en/latest/create_channel/create_channel_test_net.html)
./network.sh $1
if [ "$1" == "down" ]; then
    exit 0
elif [ "$1" == "up" ]; then
    export PATH=${PWD}/../bin:$PATH
    export FABRIC_CFG_PATH=${PWD}/configtx
    export FABRIC_CFG_PATH=${PWD}/configtx
    configtxgen -profile TwoOrgsApplicationGenesis -outputBlock ./channel-artifacts/channel1.block -channelID channel1
    #Adding orderers to channel
    for i in {1..4}; do
        if [ "$i" == "1" ]; then
            echo -n "${i}st"
            i=""
        elif [ "$i" == "2" ]; then
            echo -n "${i}nd"
        elif [ "$i" == "3" ]; then
            echo -n "${i}rd"
        elif [ "$i" == "4" ]; then
            echo -n "${i}th"
        fi
        echo " Orderer"
        export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer${i}.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
        export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer${i}.example.com/tls/server.crt
        export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer${i}.example.com/tls/server.key
        if [ "$i" == "" ]; then
            i=1
        fi
        osnadmin channel join --channelID channel1 --config-block ./channel-artifacts/channel1.block -o localhost:70$((i + 4))3 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
    done
    offset=0
    #Adding peers to channel
    for i in {1..2}; do
        echo -n "Org"
        if [ "$i" == "2" ]; then
            offset=1
        fi
        echo "${i} Peer"
        export CORE_PEER_TLS_ENABLED=true
        export CORE_PEER_LOCALMSPID="Org${i}MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${i}.example.com/peers/peer0.org${i}.example.com/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${i}.example.com/users/Admin@org${i}.example.com/msp
        export CORE_PEER_ADDRESS=localhost:$((i + 6 + offset))051
        export FABRIC_CFG_PATH=$PWD/../config/
        peer channel join -b ./channel-artifacts/channel1.block
    done
    #Setting Org 1 Peer as Anchor Peer
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    #On execution of subsequent line script errors
    #peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c channel1 --tls --cafile "$ORDERER_CA"
    echo "Deploying chaincode"
    ./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go/ -ccl go -c channel1
    echo "Invoking chaincode"
    peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" -C channel1 -n basic --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" -c '{"function":"InitLedger","Args":[]}'
    echo "Confirm the assets were added to the ledger"
    peer chaincode query -C channel1 -n basic -c '{"Args":["getAllAssets"]}'
fi
