# FlashcardSessionRequest

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**groupSlugs** | **[String]** | Nível 2 da árvore (vita-shell §1.1): slugs de disciplina. Filtra flashcardDecks.disciplineSlug. | [optional] 
**mode** | **String** | lapsed &#x3D; so cards com lapses&gt;&#x3D;1 (errados); cram &#x3D; todos os cards do escopo ignorando due (pre-prova). Added 2026-07-12 (issue #188, T4). | 
**limit** | **Int** |  | [optional] [default to 20]
**showHints** | **Bool** |  | [optional] 
**skipEasy** | **Bool** |  | [optional] 
**cardIds** | **[String]** | Fila exata para uma sessão aberta diretamente de um baralho; cada card é validado contra o usuário autenticado. | [optional] 
**deckId** | **String** |  | [optional] 
**title** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


