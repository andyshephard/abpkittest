/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/// Global custom errors for ABPKit.

/// Error cases for configuration.
/// - invalidAppGroup: App group is not valid.
/// - invalidBundlePrefix: Bundle prefix is not valid.
/// - invalidContainerURL: Bad container URL.
public
enum ABPConfigurationError: Error {
    case invalidAppGroup
    case invalidBundlePrefix
    case invalidContainerURL
}

/// Error cases for managing content blocking.
/// - invalidAppGroup: Invalid app group.
/// - invalidFilterListAttachment: Filter list attachment is invalid.
/// - invalidFilterListName: Filter list name is invalid.
/// - invalidIdentifier: Invalid ID.
public
enum ABPContentBlockerError: Error {
    case invalidAppGroup
    case invalidFilterListAttachment
    case invalidFilterListName
    case invalidIdentifier
}

/// Error cases for managing device tokens.
/// - invalidEndpoint: Endpoint URL was not found.
public
enum ABPDeviceTokenSaveError: Error {
    case invalidEndpoint
}

/// Error cases for download tasks.
/// - badAppGroup: App group was not obtained successfully.
/// - badContainerURL: Container URL is not valid.
/// - badDestinationURL: Bad destination URL for a file operation.
/// - badFilename: Bad filename for filter list rules.
/// - badFilterListModel: Bad model object.
/// - badFilterListModelName: Bad name for model object.
/// - badSourceDownload: Bad source download data.
/// - badSourceURL: URL is invalid.
/// - failedCopy: Failure during copy operation.
/// - failedFilterListModelSave: Failed to save model object.
/// - failedMove: Failure during file move operation.
/// - failedRemoval: Failure during file remove operation.
/// - failedToMakeBackgroundSession: Failed during background session creation.
/// - failedToMakeDownloadTask: Download task could not be created for the download.
/// - failedToUpdateUserDownloads: Downloads could not be updated.
/// - invalidResponse: Web server response was invalid.
/// - tooManyRequests: HTTP connection failed due to temporary state.
public
enum ABPDownloadTaskError: Error {
    case badAppGroup
    case badContainerURL
    case badDestinationURL
    case badFilename
    case badFilterListModel
    case badFilterListModelName
    case badSourceDownload
    case badSourceURL
    case failedCopy
    case failedFilterListModelSave
    case failedMove
    case failedRemoval
    case failedToMakeBackgroundSession
    case failedToMakeDownloadTask
    case failedToUpdateUserDownloads
    case invalidResponse
    case tooManyRequests
}

/// Error cases for filter list processing.
/// - aaStateMismatch: Acceptable ads state is mismatched.
/// - ambiguousModels: Model objects are not unique or are missing.
/// - badContainer: Container could not be accessed.
/// - badData: Valid data was not obtained.
/// - badSource: BlockList source is invalid.
/// - failedDecoding: Could not decode a list.
/// - failedEncodeRule: A rule could not be encoded.
/// - failedEncoding: A list model could not be encoded.
/// - failedFileCreation: Could not make a file.
/// - failedLoadModels: Could not load models.
/// - failedRemoveModels: Failed to remove model(s).
/// - failedRemoveRules: Failed to remove rules.
/// - invalidData: Data could not be read from the list.
/// - missingName: Name could not be read.
/// - missingRules: Rules could not be read.
/// - notFound: Count not find a matching filter list.
public
enum ABPFilterListError: Error {
    case aaStateMismatch
    case ambiguousModels
    case badContainer
    case badData
    case badSource
    case failedDecoding
    case failedEncodeRule
    case failedEncoding
    case failedFileCreation
    case failedLoadModels
    case failedRemoveModels
    case failedRemoveRules
    case invalidData
    case missingName
    case missingRules
    case notFound
}

/// Error cases related to mutable state.
/// - ambiguousModels: Model objects are not unique or are missing.
/// - badEnumerator: Failed to obtain enumerator.
/// - badState: Encountered invalid state.
/// - failedClear: Clearing models failed.
/// - invalidData: Indicates error with data.
/// - invalidType: Indicates error with a type.
/// - missingContainer: Storage container not found.
/// - missingDefaults: UserDefaults not found.
/// - missingDefaultsSuiteName: Suite name not found.
public
enum ABPMutableStateError: Error {
    case ambiguousModels
    case badEnumerator
    case badState
    case failedClear
    case invalidData
    case invalidType
    case missingContainer
    case missingDefaults
    case missingDefaultsSuiteName
}

/// Error cases for the user model.
/// - badDataUser: Data for user is invalid.
/// - badDownloads: Download data is invalid.
/// - failedDecodingUser: Data decoding failed.
/// - failedEncodingUser: Data encoding failed.
/// - failedUpdateData: Internal data update failed.
public
enum ABPUserModelError: Error {
    case badDataUser
    case badDownloads
    case failedDecodingUser
    case failedEncodingUser
    case failedUpdateData
}

/// Error cases for the web blocker.
/// - badURL: URL is invalid.
public
enum ABPWebViewBlockerError: Error {
    case badURL
}

/// Error cases for the rule store.
/// - invalidData: Bad/missing data.
/// - invalidName: Bad/missing name.
/// - missingRules: Rules not found.
/// - missingRuleList: Rule list not found.
/// - ruleListErrors(errorDictionary: NamedErrors): Errors named after lists in the store.
public
enum ABPWKRuleStoreError: Error {
    case invalidData
    case invalidName
    case missingRules
    case missingRuleList
    case ruleListErrors(errorDictionary: NamedErrors)
}

// ------------------------------------------------------------
// MARK: - Testing -
// ------------------------------------------------------------

/// Custom errors for ABPKit tests.

/// Error cases for download tasks.
/// - failedModelCreation: Failed when making a model object.
/// - failedSave: Unable to save data.
/// - invalidData: Unable to obtain valid data.
/// - invalidURL: Unable to obtain a valid URL.
public
enum ABPKitTestingError: Error {
    case failedModelCreation
    case failedSave
    case invalidData
    case invalidURL
}
