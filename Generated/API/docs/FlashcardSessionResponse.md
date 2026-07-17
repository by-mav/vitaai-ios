# FlashcardSessionResponse

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**sessionId** | **UUID** | UUID persistido no servidor; a fila pode ser retomada depois de fechar o app. | 
**cardIds** | **[String]** | Ordem da fila SRS (mais atrasado primeiro). | 
**totalCards** | **Int** |  | 
**expectedMinutes** | **Int** |  | 
**budget** | [**FlashcardSessionResponseBudget**](FlashcardSessionResponseBudget.md) |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


