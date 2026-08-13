export interface WorkflowAutocompleteDefinition {
  name: string;
  description?: string;
}

export interface WorkflowAutocompleteItem {
  value: string;
  label: string;
  description?: string;
}

export function workflowAutocompleteItems(
  definitions: Iterable<WorkflowAutocompleteDefinition>,
  prefix: string,
): WorkflowAutocompleteItem[] {
  return [...definitions]
    .filter((definition) => definition.name.startsWith(prefix))
    .map((definition) => ({
      value: definition.name,
      label: definition.name,
      description: definition.description,
    }));
}
