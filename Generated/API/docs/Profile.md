# Profile

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | [optional] 
**displayName** | **String** |  | [optional] 
**email** | **String** |  | [optional] 
**image** | **String** |  | [optional] 
**moment** | **String** |  | [optional] 
**year** | **Int** |  | [optional] 
**semester** | **Int** |  | [optional] 
**highSchoolYear** | **Int** |  | [optional] 
**examBoard** | **String** |  | [optional] 
**studyGoalId** | **String** |  | [optional] 
**dailyStudyMinutes** | **Int** | Meta diária de estudo em minutos (null &#x3D; não definida; UI usa 120 como fallback) | [optional] 
**university** | **String** | Short display name of the user&#39;s university (e.g. \&quot;ULBRA Porto Alegre\&quot;). Resolved via LEFT JOIN universities on user_profiles.universityId. | [optional] 
**universityState** | **String** | 2-letter state code (e.g. \&quot;RS\&quot;) from the linked universities row. | [optional] 
**universityId** | **String** |  | [optional] 
**universityLms** | **String** | Portal type the university uses. Canonical live path is canvas; moodle is reserved for future OAuth/API partner integrations. | [optional] 
**equippedSkin** | [**ProfileEquippedSkin**](ProfileEquippedSkin.md) |  | [optional] 
**subjects** | **[JSONValue]** |  | [optional] 
**stats** | **JSONValue** |  | [optional] 
**onboardingCompleted** | **Bool** |  | [optional] 
**journeyType** | [**JourneyType**](JourneyType.md) |  | [optional] 
**journeyConfig** | [**JourneyConfig**](JourneyConfig.md) |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


