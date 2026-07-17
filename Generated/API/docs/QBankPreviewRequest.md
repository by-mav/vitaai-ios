# QBankPreviewRequest

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**areaSlugs** | **[String]** | Nível 1: slugs das 6 grandes áreas (vita.exam_great_areas). | [optional] 
**disciplineSlugs** | **[String]** | Nível 2: slugs de disciplina (vita.disciplines.slug). | [optional] 
**institutionIds** | **[Int]** |  | [optional] 
**years** | [**QBankPreviewRequestYears**](QBankPreviewRequestYears.md) |  | [optional] 
**difficulties** | **[String]** |  | [optional] 
**format** | **[String]** | Filtro de formato. objective/discursive/withImage podem combinar. | [optional] 
**hideAnswered** | **Bool** | Oculta Q já respondidas pelo user. | [optional] 
**hideAnnulled** | **Bool** | Oculta Q anuladas (isCancelled&#x3D;true). | [optional] 
**hideReviewed** | **Bool** | Oculta Q em listas de revisão do user. | [optional] 
**excludeNoExplanation** | **Bool** | Default true client-side. Drop Q sem comentário substancial. | [optional] 
**includeSynthetic** | **Bool** | Default false. Se false, exclui Q geradas por IA (isSynthetic&#x3D;true). | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


