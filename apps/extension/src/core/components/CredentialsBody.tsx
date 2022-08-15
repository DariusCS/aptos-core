// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0

import {
  VStack,
  Flex,
  SimpleGrid,
  Tag,
  useDisclosure,
  Heading,
  Drawer,
  DrawerOverlay,
  DrawerContent,
  DrawerHeader,
  DrawerBody,
  Tooltip,
  useClipboard,
  Text,
} from '@chakra-ui/react';
import React from 'react';
import { CredentialRow } from 'pages/Settings';
import useGlobalStateContext from 'core/hooks/useGlobalState';

export interface CredentialHeaderAndBodyProps {
  body?: string;
  header: string;
}

export function CredentialHeaderAndBody({
  body,
  header,
}: CredentialHeaderAndBodyProps) {
  const { hasCopied, onCopy } = useClipboard(body || '');
  return (
    <VStack spacing={2} maxW="100%" alignItems="flex-start">
      <Tag>
        {header}
      </Tag>
      <Tooltip label={hasCopied ? 'Copied!' : 'Copy'} closeDelay={300}>
        <Text
          fontSize="sm"
          cursor="pointer"
          wordBreak="break-word"
          onClick={onCopy}
        >
          {body}
        </Text>
      </Tooltip>
    </VStack>
  );
}

export default function CredentialsBody() {
  const { isOpen, onClose, onOpen } = useDisclosure();
  const { activeAccount } = useGlobalStateContext();
  const { address, privateKey, publicKey } = activeAccount!;

  return (
    <>
      <SimpleGrid columns={2} width="100%" pb={4}>
        <Flex>
          <Heading fontSize="xl">Credentials</Heading>
        </Flex>
        <Flex justifyContent="right">
          <Tag size="sm" onClick={onOpen} cursor="pointer">
            View more
          </Tag>
          <Drawer
            isOpen={isOpen}
            onClose={onClose}
            placement="bottom"
          >
            <DrawerOverlay />
            <DrawerContent>
              <DrawerHeader borderBottomWidth="1px" px={4}>
                Credentials
              </DrawerHeader>
              <DrawerBody px={4}>
                <VStack mt={2} spacing={4} pb={8} alignItems="flex-start">
                  <CredentialHeaderAndBody
                    header="Private key"
                    body={privateKey}
                  />
                  <CredentialHeaderAndBody
                    header="Public key"
                    body={publicKey}
                  />
                  <CredentialHeaderAndBody
                    header="Address"
                    body={address}
                  />
                </VStack>
              </DrawerBody>
            </DrawerContent>
          </Drawer>
        </Flex>
      </SimpleGrid>
      <VStack mt={2} spacing={2} alignItems="left">
        <CredentialRow
          header="Private key"
          body={privateKey}
        />
        <CredentialRow
          header="Public key"
          body={publicKey}
        />
        <CredentialRow
          header="Address"
          body={address}
        />
      </VStack>
    </>
  );
}