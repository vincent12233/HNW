import { Global, Module } from '@nestjs/common';
import { PrivateObjectStorageService } from './private-object-storage.service';
@Global()
@Module({ providers: [PrivateObjectStorageService], exports: [PrivateObjectStorageService] })
export class StorageModule {}
