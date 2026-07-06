# StudyPackGenerateRequest

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**sourceIds** | **[String]** | Ready Studio source IDs. Backend also accepts source_ids for iOS. | 
**title** | **String** |  | [optional] 
**mode** | **String** | practice creates a QBank practice session; simulado creates a no-feedback exam-style session. | [optional] [default to .practice]
**difficulty** | **String** |  | [optional] [default to .mixed]
**questionCount** | **Int** |  | [optional] [default to 10]
**flashcardCount** | **Int** |  | [optional] [default to 15]
**includeQuestions** | **Bool** |  | [optional] [default to true]
**includeFlashcards** | **Bool** |  | [optional] [default to true]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


