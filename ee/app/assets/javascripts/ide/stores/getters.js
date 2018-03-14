export const openFilesMap = state => state.openFiles.map(path => state.entries[path]);
export const changedFilesMap = state => state.changedFiles.map(path => state.entries[path]);

export const activeFile = state => openFilesMap(state).find(file => file.active) || null;

export const canEditFile = (state) => {
  const currentActiveFile = activeFile(state);

  return state.canCommit &&
         (currentActiveFile && !currentActiveFile.renderError && !currentActiveFile.binary);
};

export const addedFiles = state => changedFilesMap(state).filter(f => f.tempFile);

export const modifiedFiles = state => changedFilesMap(state).filter(f => !f.tempFile);

export const treeList = (state) => {
  const tree = state.trees[`${state.currentProjectId}/master`];

  if (!tree) return [];

  return tree.tree;
};
